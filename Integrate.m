function [xnew, vnew, Dynamics] = Integrate(x, v, input, Dynamics, deltaT)
%
%
    
    switch Dynamics.model
    case 'FirstOrder'
        vnew = input;
        noise = Dynamics.sigma * sqrt(deltaT) * randn(size(x));
        
    case 'SecondOrder'
        vnew = v + input * deltaT;
        noise = Dynamics.sigma * sqrt(deltaT) * randn(size(x));

    case 'CoupledSDEs'
        speeds = vecnorm(v,2,2);
        theta = atan2(v(:,2), v(:,1));
        speedsnew = speeds + Dynamics.rateSpeed * (Dynamics.avgSpeed - speeds) * deltaT + Dynamics.sigmaSpeed * sqrt(deltaT) * randn(size(x,1),1);
        speedsnew = max(speedsnew, 10e-6);
        Dynamics.omega = Dynamics.omega - Dynamics.rateOmega * Dynamics.omega * deltaT + Dynamics.sigmaOmega(speedsnew) * sqrt(deltaT) .* randn(size(x,1),1);
        thetanew = mod(theta + pi + Dynamics.omega * deltaT, 2*pi) - pi ;
        vnew = speedsnew .* [cos(thetanew), sin(thetanew)];
        noise = zeros(size(x));
        
    case 'LevyWalk'
        % select tumbling agents
        tumbling = rand(size(x,1),1)<Dynamics.alpha;
        
        % tumbling agents get a new direction but keep the speed
        if sum(tumbling)
            speeds=vecnorm(v,2,2);
            new_directions=randn(size(x));
            new_directions=new_directions./vecnorm(new_directions,2,2);
            vnew(tumbling,:)=new_directions(tumbling,:).*speeds(tumbling);
        end
        
        % running agents keep the same velocity
        vnew(~tumbling,:)=v(~tumbling,:);
        
        % add input velocity
        vnew = vnew + input;
        
        noise = Dynamics.sigma * sqrt(deltaT) * randn(size(x));
        
    otherwise
        error("Dynamics.model is not valid.")
    end
    
    % velocity saturation
    if isfield(Dynamics,'vMax')
        velocities=vecnorm(vnew,2,2);
        indices=find(velocities>Dynamics.vMax);
        vnew(indices,:)= vnew(indices,:) *Dynamics.vMax ./ velocities(indices);
    end
    
    % integration
    xnew = x + vnew.*deltaT + noise;
end
