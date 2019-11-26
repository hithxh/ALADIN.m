addpath('./solver');
clear all;
clc;
import casadi.*

%% define Beale's problem [Quelle: Hock-Schittkowski-Collection Problem 35]
N   =   3;
n   =   3;
y1  =   sym('y1',[n,1],'real');
y2  =   sym('y2',[n,1],'real');
y3  =   sym('y3',[n,1],'real');

f1  =   9-8*y1(1)-6*y1(2)-4*y1(3);
f2  =   2*y2(1)^2+2*y2(2)^2+y2(3)^2;
f3  =   2*y3(1)*y3(2)+2*y3(1)*y3(3);

h1  =   -3+y1(1)+y1(2)+2*y1(3);
h2  =   [-y2(1); -y2(2)];
h3  =   -y3(3);

A1  =   [ 1,  0,  0;...
          1,  0,  0;...
          0,  1,  0;...
          0,  1,  0;...
          0,  0,  1;...
          0,  0,  1];
A2  =   [-1,  0,  0;...
          0,  0,  0;...
          0, -1,  0;...
          0,  0,  0;...
          0,  0, -1;...
          0,  0,  0];
A3  =   [ 0,  0,  0;...
         -1,  0,  0;...
          0,  0,  0;...
          0, -1,  0;...
          0,  0,  0;...
          0,  0, -1];
b   =   0;

lb1 =   [-inf; -inf; -inf];
lb2 =   [-inf; -inf; -inf];
lb3 =   [-inf; -inf; -inf];

ub1 =   [inf; inf; inf];
ub2 =   [inf; inf; inf];
ub3 =   [inf; inf; inf];

%% convert symbolic variables to MATLAB fuctions
f1f     =  matlabFunction(f1,'Vars',{y1});
f2f     =  matlabFunction(f2,'Vars',{y2});
f3f     =  matlabFunction(f3,'Vars',{y3});

h1f     =   matlabFunction(h1,'Vars',{y1});
h2f     =   matlabFunction(h2,'Vars',{y2});
h3f     =   matlabFunction(h3,'Vars',{y3});

%% initalize
maxit      =   100;
%y0        =   3*rand(N*n,1);
lam0       =   10*(rand(1)-0.5)*ones(size(A1,1),1);
rho        =   10;
mu         =   1000;
eps        =   1e-4;
term_eps   =   0;
Sig        =   {eye(n),eye(n),eye(n)};

%% solve with ALADIN
emptyfun      = @(x) [];
AQP           = [A1,A2,A3];
ffifun        = {f1f,f2f,f3f};
hhifun        = {h1f,h2f,h3f};
[ggifun{1:N}] = deal(emptyfun);

yy0         = {[0.5; 0.5; 0.5],[0.5; 0.5; 0.5],[0.5; 0.5; 0.5]};
%xx0        = {[1 1]',[1 1]'};

llbx        = {lb1,lb2,lb3};
uubx        = {ub1,ub2,ub3};
AA          = {A1,A2,A3};

opts = initializeOpts(rho, mu, maxit, term_eps);


[xoptAL, loggAL]   = run_ALADIN(ffifun,ggifun,hhifun,AA,yy0,...
                                      lam0,llbx,uubx,Sig,opts);
                                  
%% solve centralized problem with CasADi & IPOPT
y1  =   sym('y1',[n,1],'real');
y2  =   sym('y2',[n,1],'real');
y3  =   sym('y3',[n,1],'real');
f1fun   =   matlabFunction(f1,'Vars',{y1});
f2fun   =   matlabFunction(f2,'Vars',{y2});
f3fun   =   matlabFunction(f3,'Vars',{y3});
h1fun   =   matlabFunction(h1,'Vars',{y1});
h2fun   =   matlabFunction(h2,'Vars',{y2});
h3fun   =   matlabFunction(h3,'Vars',{y3});


% y0  =   ones(N*n,1);
y   =   SX.sym('y',[N*n,1]);
F   =   f1fun(y(1:3))+f2fun(y(4:6))+f3fun(y(7:9));
g   =   [h1fun(y(1:3));
         h2fun(y(4:6));
         h3fun(y(7:9));
         [A1, A2, A3]*y];
nlp =   struct('x',y,'f',F,'g',g);
cas =   nlpsol('solver','ipopt',nlp);
sol =   cas('lbx', [lb1; lb2; lb3],...
            'ubx', [ub1; ub2; ub3],...
            'lbg', [-inf;-inf;-inf;-inf;-inf;-inf;-inf;-inf;-inf;b], ...
            'ubg', [0;0;0;0;0;0;0;0;0;b]);  
        
        
% plotting
set(0,'defaulttextInterpreter','latex')
figure(2)
hold on
plot(loggAL.X')
hold on
plot(maxit,full(sol.x),'ob')
xlabel('$k$');
ylabel('$x^k$');
