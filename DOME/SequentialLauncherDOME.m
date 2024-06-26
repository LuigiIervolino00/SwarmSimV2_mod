%
%SequentialLauncher allows to set multiple values of the parameters and
%   launch multiple simulations, from different intial conditions, for each 
%   configuration and analyse the steady state results.
%   If multiple parameters are defined all the combinations are tested.
%   If 1 or 2 parameters are varied the results are plotted. 
%   It is used to study the effect of parameters on the system.
%
%   Notes:
%       Running this script can take long time (up to hours)
%       For better performances install the parallel computing toolbox
%
%   See also: Launcher, MultiLauncher
%
%   Authors:    Andrea Giusti and Gian Carlo Maffettone
%   Date:       2022
%

%% Clear environment
clear
%close all
%clc

%% Parameters

Ntimes=4;              % How many simulations are launched for each configuration

defaultParamMicroorg;  % load default parameters

seed=-1;               % seed for random generator, if negative it is not set

%% Loads DOME experiment data
experiments_folder = '/Volumes/DOMEPEN/Experiments';
experiment = '/comparisons/Euglena_switch_10/combo5';

id_folder = '/Volumes/DOMEPEN/Experiments/comparisons/Euglena_switch_10/combo5';  % folder with identification data
identification_file_name = 'identification_OLS+GB_ds1_diff.txt';

outputDir = '/Users/andrea/Library/CloudStorage/OneDrive-UniversitàdiNapoliFedericoII/Andrea_Giusti/Projects/DOME/simulations';

%% variable parameters
% One or multiple parameters can be modified at the same time.
% Parameters must be existing variables.
% The values specified here overwrite the default ones.
 
parameters(1).name='identification_file_name';
parameters(1).values=["identification_OLS+GB_ds1_diff.txt","identification_OLS+GB_ds1_diff_median.txt"];

%% Preallocate
p=cartesianProduct({parameters.values});

Nparameters=length(parameters);
Nconfig=size(p, 1);

timeInstants = 0:Simulation.deltaT:Simulation.Tmax;
window = [-Simulation.arena(1),Simulation.arena(1),-Simulation.arena(2),Simulation.arena(2)]/2;

xVec=nan(length(timeInstants),N,D);
x_f = nan(Nconfig,Ntimes,N,D);
norm_slope = nan(Nconfig, Ntimes);



%% Simulation
% for each configuration...
for i_times=1:Nconfig
    tic
    disp('Simulations batch ' + string(i_times) + ' of ' + Nconfig + ':')
    
    % assign parameters' value
    for j=1:Nparameters
        args = split(parameters(j).name,'.');
        if length(args) == 1
            assert(exist(parameters(j).name,'var'), ['Parameter ',parameters(j).name,' not present in the workspace'] )
        else
            assert(exist(string(args(1)),'var'), ["Structure "+ string(args(1)) + " not present in the workspace"] )
            assert(isfield(eval(string(args(1))), string(args(2))), ["Structure "+ string(args(1)) + " do not have field " + string(args(2))])
        end
        
        if isa(p(i_times,j),'string')
            evalin('base', strjoin([parameters(j).name, '="', p(i_times,j), '";'],'') );
        else
            evalin('base', [parameters(j).name, '=', num2str(p(i_times,j)), ';'] );
        end
        disp(['> ',parameters(j).name,' = ', num2str(p(i_times,j)) ])
    end
    
    % load identification data and instantiate simulated agents
    identification=readtable(fullfile(id_folder,identification_file_name));
    ids=randsample(length(identification.agents),N, true, ones(length(identification.agents),1));
    agents = identification(ids,:);
    Dynamics=struct('model','PTWwithInput', ...
        'avgSpeed',agents.mu_s, 'rateSpeed', agents.theta_s, 'sigmaSpeed', agents.sigma_s, 'gainSpeed', agents.alpha_s, 'gainDerSpeed', agents.beta_s,...
        'rateOmega', agents.theta_w, 'sigmaOmega', agents.sigma_w, 'gainOmega', agents.alpha_w, 'gainDerOmega', agents.beta_w,...
        'omega', normrnd(0,agents.std_w,N,1), 'oldInput', zeros(N,1));

    % load inputs data
    experiment = strrep(experiment,'_E_','_Euglena_');
    data_folder = fullfile(experiments_folder, experiment);
    if isfile(fullfile(data_folder,'inputs.txt'))   % time varying inputs
        inputs    = load(fullfile(data_folder,'inputs.txt'));
        speed_exp = load(fullfile(data_folder,'speeds_smooth.txt'));
        omega_exp = load(fullfile(data_folder,'ang_vel_smooth.txt'));
        u=inputs(:,1)/255;              %select blue channel and scale in [0,1]
        Environment.Inputs.Times  = timeInstants;
        Environment.Inputs.Values = u;
    else                                            % spatial inputs
        [mask, u]= analyseDOMEspatial(data_folder, background_sub, brightness_thresh);
        Environment.Inputs.Points = {linspace(-Simulation.arena(1),Simulation.arena(1),size(u,1))/2, linspace(-Simulation.arena(2),Simulation.arena(2),size(u,2))/2};
        Environment.Inputs.Values = flip(u,2);
    end
    
    % create initial conditions
    if seed>=0
        rng(seed,'twister'); % reproducible results
    end
    x0Data=nan(Ntimes,N,D);
    %v0 = zeros(N,D);
    speeds0 = abs(normrnd(median(identification.mean_s),median(identification.std_s),N,1));
    theta0 = 2*pi*rand(N,1)-pi;
    v0 = speeds0 .* [cos(theta0), sin(theta0)];
    for k_times=  1:Ntimes
        x0Data(k_times,:,:) = randCircle(N, 1000, D);                          % initial conditions drawn from a uniform disc
        %x0Data(k_times,:,:) = normrnd(0,0.1*sqrt(N),N,D);                   % initial conditions drawn from a normal distribution
        %x0Data(k_times,:,:) = perfectLactice(N, LinkNumber, D, true, true, (floor(nthroot(N,D)+1))^D );        % initial conditions on a correct lattice
        %x0Data(k_times,:,:) = perfectLactice(N, LinkNumber, D, true, true, (floor(nthroot(N,D)+1))^D ) + randCircle(N, delta, D); % initial conditions on a deformed lattice
    end
    
    for k_times=1:Ntimes
        % run simulation
        [xVec] = Simulator(squeeze(x0Data(k_times,:,:)), v0, Simulation, Dynamics, GlobalIntFunction, LocalIntFunction, Environment);
        
        % analyse final configuration
        xFinal=squeeze(xVec(end,:,:));
        x_f(i_times,k_times,:,:) = xFinal;
        xFinal_inWindow = squeeze(xVec(end,(xVec(end,:,1)>window(1) & xVec(end,:,1)<window(2) & xVec(end,:,2)>window(3) & xVec(end,:,2)<window(4)),:));
        
        
        if isfield(Environment,'Inputs') && isfield(Environment.Inputs,'Points')
            [density_by_input, bins, norm_sl, c_coeff] = agentsDensityByInput(Environment.Inputs.Points, Environment.Inputs.Values, xFinal_inWindow, window);
            norm_slope(i_times,k_times) = norm_sl;
        else
            [~, vVec] = gradient(xVec, 1, Simulation.deltaT, 1);
            speed = vecnorm(vVec,2,3);
            theta = atan2(vVec(:,:,2), vVec(:,:,1));
            for i=1:length(timeInstants)-1
                % angular velocity
                omega(i,:) = angleBetweenVectors(squeeze(vVec(i,:,:)),squeeze(vVec(i+1,:,:)))';
            end
            omega(length(timeInstants),:) = angleBetweenVectors(squeeze(vVec(length(timeInstants)-1,:,:)),squeeze(vVec(length(timeInstants),:,:)))';
            omega=omega/Simulation.deltaT;
            
            overlap = min(size(omega,1),size(omega_exp,1));
%             NMSE_speed(i_times,k_times) = goodnessOfFit(median(speed,2,'omitnan'), median(speed_exp,2,'omitnan'), 'NMSE');
%             NMSE_omega(i_times,k_times) = goodnessOfFit(median(abs(omega(1:end-1,:)),2,'omitnan'), median(abs(omega_exp),2,'omitnan'), 'NMSE');
%             NMSE_total(i_times,k_times) = mean([NMSE_speed(i_times,k_times), NMSE_omega(i_times,k_times)]);
            
            wmape_speed(i_times,k_times) = mape(median(speed(1:overlap,:),2,'omitnan'), median(speed_exp(1:overlap,:),2,'omitnan'),'wMAPE');
            wmape_omega(i_times,k_times) = mape(median(abs(omega(1:overlap,:)),2,'omitnan'), median(abs(omega_exp(1:overlap,:)),2,'omitnan'),'wMAPE');
            wmape_total(i_times,k_times) = mean([wmape_speed(i_times,k_times), wmape_omega(i_times,k_times)]);
        end
    end
    fprintf('Elapsed time is %.2f s.\n\n',toc)
end


%% Output in command window

fprintf('\n --- \nNtimes=%d seed=%d \n\nConfig \t|',Ntimes,seed)
for j_times=1:Nparameters
    fprintf('%s\t',string(parameters(j_times).name));
end
fprintf('\n')
for i_times=1:Nconfig
    fprintf(' %d \t|', i_times)
    for j_times=1:Nparameters
        fprintf('%.2f\t\t',string(p(i_times,j_times)));
    end
    fprintf('\n')
end

%% Plots

metrics_of_interest = {norm_slope};
metrics_of_interest = {wmape_speed, wmape_omega, wmape_total};
metrics_color = ['b','r','k'];
metrics_tags = ["wMAPE_v", "wMAPE_\omega", "wMAPE_{tot}"];

% create folder, save data and parameters
if outputDir
    counter=1;
    while exist(fullfile(outputDir,[datestr(now, 'yyyy_mm_dd_'),Dynamics.model,'_tuning',num2str(counter)]),'dir')
        counter=counter+1;
    end
    path=fullfile(outputDir, [datestr(now, 'yyyy_mm_dd_'),Dynamics.model,'_tuning',num2str(counter)]);
    mkdir(path)
    disp('Saving data in ' + string(path))
    save(fullfile(path, 'data'))
    
    fileID = fopen(fullfile(path, 'parameters.txt'),'wt');
    fprintf(fileID,'SequentialLauncher\n\n');
    fprintf(fileID,'Date: %s\n',datestr(now, 'dd/mm/yy'));
    fprintf(fileID,'Time: %s\n\n',datestr(now, 'HH:MM'));
    fprintf(fileID,'Ntimes= %d\n\n',Ntimes);
    fprintf(fileID,'Parameters:\n\n');
    fprintf(fileID,'N= %d\n',N);
    fprintf(fileID,'D= %d\n\n',D);
    fprintf(fileID,'Simulation parameters:\n');
    fprintStruct(fileID,Simulation)
    fprintf(fileID,'Changing parameters:\n');
    fprintStruct(fileID,parameters)
    fprintf(fileID,'\nDynamics:\n');
    fprintStruct(fileID,Dynamics)
    fprintf(fileID,'Environment:\n');
    fprintStruct(fileID,Environment)
    fprintf(fileID,'GlobalIntFunction:\n');
    fprintStruct(fileID,GlobalIntFunction)
    fprintf(fileID,'LocalIntFunction:\n');
    fprintStruct(fileID,LocalIntFunction)
    fprintf(fileID,'seed= %d\n',seed);
    fclose(fileID);
end



% plot if Nparameters==1
if Nparameters==1
    if isnumeric(parameters(1).values)
        figure %e_d_max and rigidity
        set(0, 'DefaultFigureRenderer', 'painters');
        subplot(2,1,1)
        hold on
        line=plotWithShade(parameters(1).values, mean(e_d_max_vec,2), min(e_d_max_vec,[],2), max(e_d_max_vec,[],2), 'b', 0.1); %e_d_max_mean(:,1),e_d_max_mean(:,2),e_d_max_mean(:,3), 'b', 0.1);
        yline(Rmax-1,'--','LineWidth',2)
        yticks(sort([0:0.1:1, Rmax-1]))
        xticks(parameters(1).values)
        set(gca,'FontSize',14)
        ylabel('$e$', 'Interpreter','latex','FontSize',22, 'rotation',0,'VerticalAlignment','middle')
        box on
        grid
        
        subplot(2,1,2)
        rigidity_line=plot(parameters(1).values, mean(rigid_vec,2),'Marker','o','Color','r','LineWidth',2,'MarkerSize',6);
        xticks(parameters(1).values)
        yticks([0:0.25:1])
        xlabel(parameters(1).name)
        set(gca,'FontSize',14)
        xlabel('$\delta$', 'Interpreter','latex','FontSize',22)
        ylabel('$\rho$', 'Interpreter','latex','FontSize',22, 'rotation',0,'VerticalAlignment','middle')
        box on
        grid
        if outputDir
            saveas(gcf,fullfile(path, 'e_rho'))
            saveas(gcf,fullfile(path, 'e_rho'),'png')
        end
    
    else
        figure
        hold on
        for i=1:length(metrics_of_interest)
        plots(i,:)=scatter([1:Nconfig]-(length(metrics_of_interest)-1)*0.1+(i-1)*0.2,metrics_of_interest{i},metrics_color(i));
        end
        xticks([1:Nconfig])
        xticklabels(parameters(1).values)
        set(gca, 'TickLabelInterpreter', 'none');
        xlim([0,Nconfig+1])
        ylim([0, max([metrics_of_interest{:}],[],'all')*1.1])
        legend(plots(:,1),metrics_tags)
        set(gca,'FontSize',14)
        box on
        if outputDir
        saveas(gcf,fullfile(path, 'metrics'))
        saveas(gcf,fullfile(path, 'metrics'),'png')
        end
    end
    
elseif Nparameters==2
    % average over the initial conditions
    links_mean = mean(links,2);
    rigid_mean = mean(rigid_vec,2);
%     e_d_max_mean = mean(e_d_max_vec,2);
%     e_d_max_map = reshape(e_d_max_mean, [length(parameters(1).values), length(parameters(2).values)]);
    
    norm_slope_mean = mean(norm_slope,2);
    norm_slope_map = reshape(norm_slope_mean, [length(parameters(1).values), length(parameters(2).values)]);
    
    figure
    [~,lplot]=mysurfc(parameters(1).values, parameters(2).values, norm_slope_map);
    xlabel(parameters(1).name)
    xlabel('$\beta_v$','Interpreter','latex','FontSize',18)
    ylabel(parameters(2).name)
    ylabel('$\alpha_\omega$','Interpreter','latex','FontSize',18)
    ylabel('$\beta_\omega$','Interpreter','latex','FontSize',18)
    title('Photoaccumulation Index')
    hold on
    xlim([-inf, inf])
    ylim([-inf, inf])
    set(gca, 'XTick', parameters(1).values);
    set(gca, 'YTick', parameters(2).values);
    set(gca,'FontSize',14)
    caxis([-1,1])
    if outputDir
        saveas(gcf,fullfile(path, 'norm_slope'))
        saveas(gcf,fullfile(path, 'norm_slope'),'png')
    end
    
    % SWARM
    figure
    swarms_to_show=min([Nconfig, 6]);
    n_x = length(parameters(1).values);
    n_y = length(parameters(2).values);
    f=tiledlayout(n_y,n_x, 'TileSpacing','tight', 'Padding','tight');
    for i_y=1:n_y
        for i_x=1:n_x
            nexttile(sub2ind([length(parameters(1).values), length(parameters(2).values)], i_x, i_y))
            if isfield(Environment,'Inputs') && isfield(Environment.Inputs,'Points')
            plotEnvField(Environment.Inputs.Points, Environment.Inputs.Values, Simulation.arena)
            end
            plotSwarmInit(squeeze(x_f(sub2ind([length(parameters(1).values), length(parameters(2).values)], i_x, i_y),1,:,:)), Simulation.Tmax, inf, inf, Simulation.arena);
            xticks([]); yticks([])
            title([parameters(1).name,'=' num2str(parameters(1).values(i_x)),' ', parameters(2).name,'=' num2str(parameters(2).values(i_y))])
            title(['\beta_v=' num2str(parameters(1).values(i_x)),' ','\beta_\omega=' num2str(parameters(2).values(i_y))])
        end
    end
    set(gcf,'Position',[100 500 200*swarms_to_show 300*2])
    if outputDir
        saveas(gcf,fullfile(path, 'x'))
        saveas(gcf,fullfile(path, 'x'),'png')
    end
end





