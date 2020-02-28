function [ loc, timers, opts ] = parallelStep( sProb, iter, timers, opts )
%PARALLELSTEP Summary of this function goes here
NsubSys = length(sProb.AA);

% solve local problems
for j=1:NsubSys % parfor???
    nngi{j} = size(sProb.locFunsCas.ggi{j},1);
    nnhi{j} = size(sProb.locFunsCas.hhi{j},1);    
    
    % set up parameter vector for local NLP's
    pNum = [ iter.stepSizes.rho;
             iter.lam;
             iter.yy{j}];

    
    % solve local NLP's
    tic
    sol = sProb.nnlp{j}('x0' ,    iter.yy{j},...
                        'lam_g0', iter.KKapp{j},...
                        'lam_x0', iter.LLam_x{j},...
                        'p',      [pNum; opts.SSig{j}(:)],...
                        'lbx',    sProb.llbx{j},...
                        'ubx',    sProb.uubx{j},...
                        'lbg',    sProb.gBounds.llb{j}, ...
                        'ubg',    sProb.gBounds.uub{j});     

    % collect variables 
    [ loc.xx{j}, loc.KKapp{j}, loc.LLam_x{j} ] = deal(full(sol.x), ...
                                         full(sol.lam_g), full(sol.lam_x));
    timers.NLPtotTime = timers.NLPtotTime + toc;                           

    % primal active set detection
    loc.inact{j}    = logical([false(nngi{j},1); ...
                      full(sProb.locFuns.hhi{j}(loc.xx{j}) < opts.actMargin)]);
    KKapp{j}(loc.inact{j}) = 0;

    
    % dynamically changing \Sigma?
    if strcmp(opts.Sig,'dyn')
        % after second iteration 
        if size(iter.logg.X,2) > 2 
            [opts.SSig{j}, loc.locStep{j}] = computeDynSig(opts.SSig{j},...
                               iter.yy{j} - loc.xx{j},iter.loc.locStep{j});
        else
            loc.locStep{j} = iter.yy{j} - loc.xx{j};
        end
    end

    % evaluate sensitivities locally
    % Hessians
    tic
    loc.sensEval.ggiEval{j} = sProb.sens.gg{j}(loc.xx{j});
    if strcmp(opts.Hess, 'BFGS') || strcmp(opts.Hess, 'DBFGS')
        loc.sensEval.gLiEval{j}   = sProb.sens.gL{j}(loc.xx{j},loc.KKapp{j});
        if ~isfield(iter.loc, 'sensEval')
            loc.sensEval.HHiEval{j}   = eye(length(sProb.zz0{j}));
        else
            loc.sensEval.HHiEval{j}   = BFGS(iter.loc.sensEval.HHiEval{j},...
                                             loc.sensEval.gLiEval{j},...
                                             iter.loc.sensEval.gLiEvalOld{j},...
                                             loc.xx{j},...
                                             iter.loc.xxOld{j},...
                                             opts.Hess);
        end
    else
        loc.sensEval.HHiEval{j}   = sProb.sens.HH{j}(loc.xx{j},loc.KKapp{j},iter.stepSizes.rho);
    end 

    % Jacobians of active nonlinear constraints/bounds
    JacCon           = full(sProb.sens.JJac{j}(loc.xx{j}));    
    JacBounds        = eye(size(loc.xx{j},1));

    % eliminate inactive entries  
    JJacCon{j}       = sparse(JacCon(~loc.inact{j},:));      
    JacBounds        = JacBounds((sProb.llbx{j} - loc.xx{j})  ...
           > opts.actMargin |(loc.xx{j}-sProb.uubx{j}) > opts.actMargin,:);
    loc.sensEval.JJacCon{j}      = [JJacCon{j}; JacBounds];     
    timers.sensEvalT = timers.sensEvalT + toc;
    
    % for reduced-space method, compute reduced QP
    if strcmp(opts.slack,'redSpace') && strcmp(opts.innerAlg, 'none')

        loc.sensEval.ZZ{j}    = null(full(JJacCon{j}));
        loc.sensEval.HHred{j} = loc.sensEval.ZZ{j}'* ...
                          full(loc.sensEval.HHiEval{j})*loc.sensEval.ZZ{j};
        loc.sensEval.AAred{j} = sProb.AA{j}*loc.sensEval.ZZ{j};
        loc.sensEval.ggred{j} = loc.sensEval.ZZ{j}'*full(loc.sensEval.ggiEval{j});

        % regularize reduced Hessian
        tic
        if strcmp(opts.reg,'true')
            loc.sensEval.HHred{j}  = regularizeH(loc.sensEval.HHred{j}, opts);
        end
        timers.RegTotTime = timers.RegTotTime + toc;        
    else
        % regularization full Hessian
        tic
        if strcmp(opts.reg,'true')
            loc.sensEval.HHiEval{j} = ...
                                 regularizeH(loc.sensEval.HHiEval{j},opts);
        end
        timers.RegTotTime = timers.RegTotTime + toc;
    end
end 

% save information for next BFGS iteration
if strcmp(opts.Hess, 'BFGS') || strcmp(opts.Hess, 'DBFGS')
    loc.sensEval.gLiEvalOld = loc.sensEval.gLiEval;
    loc.xxOld               = loc.xx;
end
 
end

