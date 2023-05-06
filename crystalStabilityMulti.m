%
%crystalStabilityMulti Allows to generate random triangular configurations and perform local analysis.
%
%   See also: Launcher
%   
%   Authors:    Andrea Giusti
%   Date:       2023
%

close all
clear
clc

%% Parameters

D=2; %number of dimensions [2 or 3]

% interaction function
syms x
%a=0.5; c=24; f(x)= a/x^(c*2)-a/x^c %Lennard-Jones
f(x)= -(x-1) %linear

epsilon = 10e-9; % value approximated to zero

Nagents = 4;%[25:30];
Ntimes = 1;

LinkNumber=6*(D-1);   %number of links (6=triangular lattice, 4=square lattice, 3=hexagonal lattice) (L)
Rmax= (sqrt(5-D)+1)/2;    % maximum lenght of a link (R_a). Must be in [1; Rnext]

Nconfig=length(Nagents);
rigidity = nan(Nconfig,Ntimes);
equilibrium = nan(Nconfig,Ntimes);
stability = nan(Nconfig,Ntimes);
asim_stability = nan(Nconfig,Ntimes);
rigid_motion = nan(Nconfig,Ntimes);
hyperbolic = nan(Nconfig,Ntimes);
lambda= nan(Nconfig,Ntimes,9);

figure
tiledlayout(4,6,'TileSpacing','Compact','Padding','Compact');

for conf=1:Nconfig
    
    N=Nagents(conf);
    lattice_size=(floor(nthroot(N,D)+1))^D;
    
    disp(['Evaluating ',num2str(Ntimes),' configurations with N=',num2str(N),' and lattice_size=',num2str(lattice_size)])
    
    for rep =1:Ntimes
        
        % generic lattice
        X=perfectLactice(N, LinkNumber, D,true,true,lattice_size, 10^6);
        
        % build all links
        links=buildLinks(X, Rmax, false);
        
        %% Build incidence matrix
        n=size(X,1);
        m=size(links,1);
        B = buildIncidenceMatrixFromLinks(links,n);
        
        %% Define Matrices and Useful Quantities
        R=B'*X;                         %realative positions
        L=B*B';                         % Laplacian
        A=L-diag(diag(L));              % adjacency matrix
        % Le=B'*B;                        % edge laplacian
        % Ae=(Le~=0)-eye(m);              % adjacency matrix of the graph of the edges
        M = buildRigidityMatrix(X, B);  % rigidity matrix
        
        xvec = reshape(X',[],1);    % stack vector of positions
        rvec = reshape(R',[],1);    % stack vector of relative positions
        
        d=vecnorm(R,2,2);   %vector of distances
        Rhat=R./d;          %unit vectors of relative positions
        
        df=diff(f,x); % derivative of f
        
        %cosines=Rhat*Rhat'; % scalar vectors between unit vectors
        
        %% Analyse the configuration
        % infinitesimal rigidity
        rigidity(conf,rep) = rank(M)==D*N-D*(D+1)/2;
        
        equilibrium(conf,rep) = all(f(d)==0);
        
        %% Compute the Jacobian
        % Jacobian of the system of the distances
        %J=(Le*diag(df(d))).*cosines
        
        % Jacobian of the system of the positions
        %dG=nan(m,m,2*n);
        J=sparse(D*n,D*n);
        gamma = eval((df(d).*d - f(d)).*d.^-3);
        diag_gamma=sparse(diag(gamma));
        for k=1:(D*n)
            %dG(:,:,k)=diag(gamma) * diag(M(:,k));
            dG=sparse(diag_gamma * diag(M(:,k)));
            J(:,k)=kron(B * dG * B', eye(D)) * xvec;
        end
        
        %J=jordan(J)
        
        %% Analysis
        % analyse the Jacobian
        %[V,lambda] =eig(J);
        [V,lam]=eigs(J,9,'largestreal','Tolerance',epsilon/2,'MaxIterations',10^6);
        lam=diag(lam);
        
        % study equilibrium
        lam=vpa(subs(lam),3);
        lambda(conf,rep,:)=lam;
        hyperbolic(conf,rep)= all((real(lam) < -epsilon) | (real(lam) > epsilon));
        stability(conf,rep)= all(real(lam) < epsilon);
        asim_stability(conf,rep)= all(real(lam) < -epsilon);
        
        % get basis of the center manifold
        V0=V(:, -epsilon<real(lam) & real(lam)<epsilon);
        
        % check if the center manifold correspons to rigid motions
        if rigidity(conf,rep)
            rigid_motion(conf,rep) = norm(M*V0)<epsilon;
        end
        
        % check data are correct
        if ~rigidity(conf,rep) || ~equilibrium(conf,rep) || ~stability(conf,rep) || ~rigid_motion(conf,rep) || asim_stability(conf,rep)
            error('Conditions not satisfied. Execution interrupted.')
        end
        
    end
    
    % print a sample config for various number of agents
    if ismember(conf, round(linspace(1,Nconfig,24)))
        nexttile
        plotSwarmInit(X,N,0,1.5)
        set(gca,'YTickLabel',[]);
        set(gca,'XTickLabel',[]);
        drawnow
    end
end

%% Display Results
disp(['rigidity=       ',num2str(all(rigidity,'all')), ' (expected 1)'])
disp(['equilibrium=    ',num2str(all(equilibrium,'all')), ' (expected 1)'])
disp(['stability=      ',num2str(all(stability,'all')), ' (expected 1)'])
disp(['asim_stability= ',num2str(any(asim_stability,'all')), ' (expected 0)'])
disp(['rigid_motion=   ',num2str(all(rigid_motion,'all')), ' (expected 1)'])

%% Plots
% figure
% plot(graph(A),'XData',X(:,1),'YData',X(:,2), 'EdgeLabel', [1:m],'MarkerSize',10)
% axis equal
% title('lattice')

% figure
% plot(graph(Ae),'MarkerSize',10)
% axis equal
% title('edge graph')

% figure
% plot(real(lam),imag(lam),'o')
% hold on
% plot(0,0,'r*')
% plot([0,0],[-100,100],'r--')
% grid
% title('poles')

% figure
% fplot(f,[0,2])
% hold on
% scatter(1,0)
% ylim([-inf 1])
% grid
% title('f(x)')
% axis([0,2,-0.5, 1.1])


