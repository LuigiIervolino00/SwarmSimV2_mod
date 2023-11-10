clear
close all


theta   = 0.5;
mu      = 5;
sigma   = 0.5;
alpha   = -0.3;
beta    = -3;

Tmax    = 100;
dT      = 0.01; % integration step
deltaT  = 1; % sampling time
Ntimes  = 10;
times = [0:dT:Tmax];
% u = zeros(size(times));            % no input
u = times>Tmax/3 & times<Tmax*2/3;  % step
% u = times*Tmax;                     % ramp
% u = sin(times/10);                  % sine wave
% u = mod(times,10)/10;               % sawtooth wave

u_dot = [diff(u),0]/dT;
X=nan(length(times),Ntimes);
X(1,:)=rand(1,Ntimes)*2*mu;
for i=1:length(times)-1
    X(i+1,:)= X(i,:) + (theta*(mu-X(i,:)) + alpha*u(i) + beta*u_dot(i) )*dT + sigma* sqrt(dT) * randn(1,Ntimes);
end

X_data=X(1:deltaT/dT:end,:);
u_data=u(1:deltaT/dT:end)';
%times=times(1:deltaT/dT:end);

[m_LASSO, t_LASSO, s_LASSO, a_LASSO]= SDE_parameters_est(X_data, [u_data, [diff(u_data);0]/deltaT], deltaT, 'LASSO');
[m_OLS, t_OLS, s_OLS, a_OLS]        = SDE_parameters_est(X_data, [u_data, [diff(u_data);0]/deltaT], deltaT, 'OLS');
[m_MLE, t_MLE, s_MLE]               = MLE_SDE_parameters(X_data, deltaT);

fprintf('Parameters: Tmax=%.1f\tdT=%.3f\tdeltaT=%.3f\tNtimes=%d\n', Tmax, dT, deltaT, Ntimes)
fprintf('Parameters: mean(data)=%.3f\tstd(data)=%.3f\n\n', mean(X_data(:)), std(X_data(:)))
fprintf('\ttheta\tmu\tsigma\talpha\tbeta\n')
fprintf('TRUE\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f\n',theta,mu,sigma,alpha,beta)
fprintf(join(['LASSO\t%.2f\t%.2f\t%.2f',repmat("%.2f",1,length(mean(a_LASSO))),'\n'],'\t'),mean(t_LASSO),  mean(m_LASSO),  mean(s_LASSO),  mean(a_LASSO))
fprintf(join(['OLS\t%.2f\t%.2f\t%.2f',repmat("%.2f",1,length(mean(a_OLS))),'\n'],'\t'),  mean(t_OLS),    mean(m_OLS),    mean(s_OLS),  mean(a_OLS))
fprintf('MLE\t%.2f\t%.2f\t%.2f\n',  mean(t_MLE),    mean(m_MLE),    mean(s_MLE))

x_sim=nan(length(times),1);
x_sim(1)=mean(m_OLS);
for i=1:length(times)-1
    x_sim(i+1)= x_sim(i) + (mean(t_OLS)*(mean(m_OLS)-x_sim(i)) + mean(a_OLS(:,1))*u(i) + mean(a_OLS(:,2))*u_dot(i) )*dT;
end

figure; 
subplot(2,1,1)
hold on
plot(times, X, color=[0.5,0.5,0.5])
plot(times, x_sim, 'r', LineWidth=1)
subplot(2,1,2)
plot(times, u)