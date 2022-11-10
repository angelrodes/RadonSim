%% init
% clc
clear
close all hidden

%% Display info
disp('----------------------')
disp('Radon Simulator')
disp('Angel Rodes, 2022')
disp('www.angelrodes.com')
disp('----------------------')
disp('Downlaod csv from:')
disp('    https://dashboard.airthings.com/devices/')


%% Select files (Radon data and air circulation)

% radon_data_file='2930129618-latest(47).csv';
% ventilation_file='Office217.csv';
% ventilation_file='Office217_one_week.csv';
% ventilation_file='AR_flat_LR_all.csv';

[file,path] = uigetfile('*','Radon data file');
radon_data_file=fullfile(path,file);

[file,path] = uigetfile('*','Air circulation file');
ventilation_file=fullfile(path,file);


%% read radon data
selectedfile=radon_data_file;

fid = fopen(selectedfile);

disp(['File: ' selectedfile])

% recorded;RADON_SHORT_TERM_AVG Bq/m3;TEMP °C;HUMIDITY %;PRESSURE hPa;CO2 ppm;VOC ppb
% mydata = textscan(fid, '%s %f %f %f %f %f %f ',...
%     'HeaderLines', 1,'Delimiter',';');
% 2022-09-22T10:10:33;;25.61;47.50;986.00;547.00;46.00
mydata = textscan(fid, '%f-%f-%fT%f:%f:%f %f %f %f %f %f %f ',...
    'HeaderLines', 1,'Delimiter',';');
fclose(fid);
input.yyyy=mydata{1};
input.MM=mydata{2};
input.dd=mydata{3};
input.HH=mydata{4};
input.mm=mydata{5};
input.ss=mydata{6};
input.Rn=mydata{7};
input.T=mydata{8};
input.H=mydata{9};
input.P=mydata{10};
input.CO2=mydata{11};
input.VOC=mydata{12};

% get posix and yyyyMMddHHmmss times
input.posix_time=input.yyyy.*0+NaN;
input.numeric_time=input.yyyy.*0+NaN;
for n=1:numel(input.yyyy)
    if mod(input.yyyy(n),4)==0 % check lap year
        days_in_month=[31,29,31,30,31,30,31,31,30,31,30,31];
    else
        days_in_month=[31,28,31,30,31,30,31,31,30,31,30,31];
    end
    % approx posix times
    input.posix_time(n)=...
        (input.yyyy(n)-1970)*365.25*24*60*60+...
        (sum(days_in_month(1:input.MM(n)))-days_in_month(input.MM(n)))*24*60*60+...
        input.dd(n)*24*60*60+...
        input.HH(n)*60*60+...
        input.mm(n)*60+...
        input.ss(n);
    input.numeric_time(n)=...
        input.ss(n)+...
        input.mm(n)*1e2+...
        input.HH(n)*1e4+...
        input.dd(n)*1e6+...
        input.MM(n)*1e8+...
        input.yyyy(n)*1e10;
    % day_in_week(n)=weekday([num2str(yyyy) '/' num2str(MM) '/' num2str(dd)]); % 1: Sunday , 2: Monday , etc.
end

disp(['    First data: ' num2str(input.numeric_time(1))])
disp(['    Last update: ' num2str(input.numeric_time(end))])

%% read ventilation data
selectedfile=ventilation_file;

fid = fopen(selectedfile);

disp(['File: ' selectedfile])

% recorded;RADON_SHORT_TERM_AVG Bq/m3;TEMP °C;HUMIDITY %;PRESSURE hPa;CO2 ppm;VOC ppb
% mydata = textscan(fid, '%s %f %f %f %f %f %f ',...
%     'HeaderLines', 1,'Delimiter',';');
% 2022-09-22T10:10:33;;25.61;47.50;986.00;547.00;46.00
mydata = textscan(fid, '%f-%f-%fT%f:%f:%f %s ',...
    'HeaderLines', 1,'Delimiter',';');
fclose(fid);
ventilation.yyyy=mydata{1};
ventilation.MM=mydata{2};
ventilation.dd=mydata{3};
ventilation.HH=mydata{4};
ventilation.mm=mydata{5};
ventilation.ss=mydata{6};
ventilation.strings=mydata{7};


% get posix and yyyyMMddHHmmss times
ventilation.posix_time=ventilation.yyyy.*0+NaN;
ventilation.numeric_time=ventilation.yyyy.*0+NaN;
% n_place=0;
location_strings=[];
for n=1:numel(ventilation.yyyy)
    if mod(ventilation.yyyy(n),4)==0 % check lap year
        days_in_month=[31,29,31,30,31,30,31,31,30,31,30,31];
    else
        days_in_month=[31,28,31,30,31,30,31,31,30,31,30,31];
    end
    % approx posix times
    ventilation.posix_time(n)=...
        (ventilation.yyyy(n)-1970)*365.25*24*60*60+...
        (sum(days_in_month(1:ventilation.MM(n)))-days_in_month(ventilation.MM(n)))*24*60*60+...
        ventilation.dd(n)*24*60*60+...
        ventilation.HH(n)*60*60+...
        ventilation.mm(n)*60+...
        ventilation.ss(n);
    ventilation.numeric_time(n)=...
        ventilation.ss(n)+...
        ventilation.mm(n)*1e2+...
        ventilation.HH(n)*1e4+...
        ventilation.dd(n)*1e6+...
        ventilation.MM(n)*1e8+...
        ventilation.yyyy(n)*1e10;
    % day_in_week(n)=weekday([num2str(yyyy) '/' num2str(MM) '/' num2str(dd)]); % 1: Sunday , 2: Monday , etc.
    
    %     if strncmpi(ventilation.strings{n},'Place',5)
    %         n_place=n_place+1;
    %         placestring=ventilation.strings{n};
    %         location_strings=[location_strings , placestring(7:end)];
    %     end
    %     ventilation.location(n)=n_place;
end

ventilation.open=strncmpi(ventilation.strings,'Open',4);
% ventilation.closed=strncmpi(ventilation.strings,'Close',5); % not needed

disp(['    First data: ' num2str(ventilation.numeric_time(1))])
disp(['    Last update: ' num2str(ventilation.numeric_time(end))])

%% define time space and day strings

% time every 5 min
% unique_days=unique(floor(input.numeric_time/1e6)*1e6);
unique_days_input=unique(floor(input.numeric_time/1e6)*1e6);
unique_days_ventilated=unique(floor(ventilation.numeric_time/1e6)*1e6);
unique_days=...
    unique_days_input(...
    unique_days_input>=min(unique_days_ventilated) & ...
    unique_days_input<=max(unique_days_ventilated) );
n=0;
for day_numeric=unique_days'
    for hour=0:23
        for minute=0:5:55
            n=n+1;
            model.numeric_time(n)=day_numeric+hour*1e4+minute*1e2;
            year=floor(day_numeric/1e10);
            month=floor(day_numeric/1e8)-year*100;
            day=floor(day_numeric/1e6)-month*100-year*10000;
            model.posix_time(n)=...
                (year-1970)*365.25*24*60*60+...
                (sum(days_in_month(1:month))-days_in_month(month))*24*60*60+...
                day*24*60*60+...
                hour*60*60+...
                minute*60+...
                0;
        end
    end
    
end

model.numeric_time_ticks=unique_days;
%position of the day strings
model.posix_time_ticks=interp1(model.numeric_time,model.posix_time,model.numeric_time_ticks,'nearest','extrap');
wdaystrings=[{'Su'},{'Mo'},{'Tu'},{'We'},{'Th'},{'Fr'},{'Sa'}];
prevmonth=0;
for n=1:numel(model.posix_time_ticks)
    timestring=num2str(model.numeric_time_ticks(n));
    model.day_in_week(n)=weekday([timestring(1:4) '/' timestring(5:6) '/' timestring(7:8)]); % 1: Sunday , 2: Monday , etc.
    if n==1 || prevmonth~=str2double(timestring(5:6))
        tick_string=[wdaystrings{model.day_in_week(n)} '.' num2str(timestring(7:8)) '/' num2str(timestring(5:6))];
    else
        tick_string=[wdaystrings{model.day_in_week(n)} '.' num2str(timestring(7:8))];
    end
    prevmonth=str2double(timestring(5:6));
    % day strings
    model.time_strings{n}=tick_string;
end

% define place and ventilated
model.ventilated=0.*model.posix_time;
model.location=0.*model.posix_time;
for n=1:numel(model.posix_time)
    if sum(ventilation.posix_time<=model.posix_time(n))==0
        model.ventilated(n)=ventilation.open(1);
        %         model.location(n)=ventilation.location(1);
    else
        model.ventilated(n)=ventilation.open(find(ventilation.posix_time<=model.posix_time(n),1,'last'));
        %         model.location(n)=ventilation.location(find(ventilation.posix_time<=model.posix_time(n),1,'last'));
    end
end


%% Undo the Rn 24h average (inverse moving average)

Rn_index=~isnan(input.Rn);

input.delta_Rn_time=input.Rn*NaN;
input.delta_Rn_time(Rn_index)=[median(diff(input.posix_time(Rn_index)));diff(input.posix_time(Rn_index))];

input.instant_Rn=input.Rn*NaN;

for n=find(Rn_index)'
    data_index=find(...
        ~isnan(input.delta_Rn_time) &...
        input.posix_time < input.posix_time(n) &...
        input.posix_time >= input.posix_time(n)- 24*60*60 ...
        );
    
    delta_times=input.delta_Rn_time(data_index);
    
    if ~isempty(data_index)
        delta_times(1)=24*60*60-input.delta_Rn_time(n)-sum(input.delta_Rn_time(data_index))+input.delta_Rn_time(data_index(1));
    end
    
    %     if sum(delta_times)+input.delta_Rn_time(n)~=24*60*60
    %         warning(['Wrong time sum n=' num2str(n) ' sum=' num2str((sum(delta_times)+input.delta_Rn_time(n))/60/60) ' hours'])
    %     end
    
    input.instant_Rn(n)=(...
        input.Rn(n) * 24*60*60 - ...
        sum( input.instant_Rn(data_index) .* delta_times )...
        )/input.delta_Rn_time(n);
    input.instant_Rn(n)=max(0,input.instant_Rn(n));
end

% create instant model

model.instant_Rn=model.posix_time.*NaN;
for n=1:numel(model.instant_Rn)
    select=find(~isnan(input.instant_Rn) & input.posix_time>model.posix_time(n),1,'first');
    if ~isempty(select)
        model.instant_Rn(n)=input.instant_Rn(select);
    else
        model.instant_Rn(n)=NaN;
    end
end

% re do 24 h average
model.instant_averaged_24h=model.instant_Rn*NaN;
for n=24*60*60/median(diff(model.posix_time)):numel(model.posix_time)
    data=model.instant_Rn(model.posix_time<=model.posix_time(n) &...
        model.posix_time>model.posix_time(n)-24*60*60);
    model.instant_averaged_24h(n)=mean(data);
end

%% Run models

% define number of models to run
n_random_models=150;
n_convergence=150;
n_2s_models=300;
n_models=n_random_models+n_convergence+n_2s_models;

% define parameters
minimum_rates=range(model.instant_Rn)/range(model.posix_time)/10;
maximum_rates=range(model.instant_Rn)/min(diff(model.posix_time));
minimum_Rn=10;
maximum_Rn=max(model.instant_Rn)*10;
% min_Rn max_Rn venitlation_rate accumulation_rate
% first line = minimum values ; second line = maximum value
parameter_limits_0=[...
    minimum_Rn minimum_Rn minimum_rates minimum_rates ;...
    maximum_Rn maximum_Rn maximum_rates maximum_rates ...
    ];
parameter_limits=parameter_limits_0;

model.parameters=parameter_limits(1,:) .* ...
    ( parameter_limits(2,:)./parameter_limits(1,:) ).^rand(n_models,4);

model.concentrations=NaN.*zeros(n_models,numel(model.posix_time));
model.red_chi_square=NaN.*zeros(n_models,1);
model.average_24h=NaN.*zeros(n_models,numel(input.Rn));

% run models
h = waitbar(0,'Running models...');
for n=1:n_models
    if n>1
        waitbar(n/n_models,h,['n=' num2str(n) ' ; \chi^2_\nu=' num2str(min(model.red_chi_square),3)])
    end
    % recalculate parameters (convergence)
    %     disp('recalculate parameters (convergence)')
    %     tic
    if n>n_random_models
        if n<n_random_models+n_convergence
                sorted_red_chi_square=sort(model.red_chi_square);
                select=model.red_chi_square<=sorted_red_chi_square(ceil(n/10));
                expand_limits=2;
                parameter_limits=[...
                    min(model.parameters(select,:))./expand_limits ; ...
                    max(model.parameters(select,:)).*expand_limits ...
                    ];
        else
            if sum(model.red_chi_square<min(model.red_chi_square)+2)>8
                parameter_limits=[...
                    min(model.parameters(model.red_chi_square<min(model.red_chi_square)+2,:)) ; ...
                    max(model.parameters(model.red_chi_square<min(model.red_chi_square)+2,:)) ...
                    ];
            else
                sorted_red_chi_square=sort(model.red_chi_square);
                select=model.red_chi_square<=sorted_red_chi_square(8);
                parameter_limits=[...
                    min(model.parameters(select,:)) ; ...
                    max(model.parameters(select,:)) ...
                    ];
            end
        end
        model.parameters(n,:)=parameter_limits(1,:) .* ...
            ( parameter_limits(2,:)./parameter_limits(1,:) ).^rand(1,4);
    end
    model.parameters(n,1)=min(model.parameters(n,1), model.parameters(n,2)); % force min<=max
    params=model.parameters(n,:); % min_Rn max_Rn venitlation_rate accumulation_rate
    %     toc
    
    % calculate model
    %     disp('calculate model')
    %     tic
    for m=1:numel(model.ventilated)
        if m==1
            concentration=params(1)*(model.ventilated(1)==1)+params(2)*(model.ventilated(1)==0);
        elseif model.ventilated(m)==0
            concentration=concentration+params(4)*(model.posix_time(m)-model.posix_time(m-1));
        else
            concentration=concentration-params(3)*(model.posix_time(m)-model.posix_time(m-1));
        end
        concentration=max(concentration,params(1));
        concentration=min(concentration,params(2));
        model.concentrations(n,m)=concentration;
    end
    %     toc
    
    % calculate 24 h average
    %     disp('calculate 24 h average')
    %     tic
    Ci=model.concentrations(n,:);
    C24h=NaN.*Ci;
    for m=24*60*60/median(diff(model.posix_time)):round(30*60/median(diff(model.posix_time))):numel(model.posix_time)
        data=Ci(model.posix_time<=model.posix_time(m) &...
            model.posix_time>model.posix_time(m)-24*60*60);
        C24h(m)=mean(data);
    end
    %     toc
    %     disp('interpolate 24 h average')
    %     tic
    sel=~isnan(C24h);
    model.average_24h(n,:)=interp1(model.posix_time(sel),C24h(sel),input.posix_time);
    %     toc
    
    % calculate reduced chi square
    select=~isnan(model.average_24h(n,:)'-input.Rn);
    dof=sum(select)-4;
    model.red_chi_square(n,1)=sum((model.average_24h(n,select)'-input.Rn(select)).^2./input.Rn(select))/dof;
    
end
close(h)

%% select best result
select=find(model.red_chi_square==min(model.red_chi_square),1,'first');
best_params=model.parameters(select,:); % min_Rn max_Rn venitlation_rate accumulation_rate
bestmodel_concentrations=model.concentrations(select,:);
bestmodel_24h_average=model.average_24h(select,:);

onesigma= (model.red_chi_square<min(model.red_chi_square)+1 );
onesigma_params=model.parameters(onesigma,:);


% display results
disp('----------------------')
disp('Fitting results and [one sigma range]:')
disp(['    Reduced chi-squared: ' num2str(min(model.red_chi_square))])
disp(['    N models in 1-sigma: ' num2str(sum(onesigma))])
disp(['    [Rn]min: ' num2str(best_params(1),3) ' [' num2str(min(onesigma_params(:,1)),3) '-' num2str(max(onesigma_params(:,1)),3) '] Bq/m3'])
disp(['    [Rn]max: ' num2str(best_params(2),3) ' [' num2str(min(onesigma_params(:,2)),3) '-' num2str(max(onesigma_params(:,2)),3) '] Bq/m3'])
disp(['    Ventilation  rate: ' num2str(best_params(3)*60*60,3) ' [' num2str(min(onesigma_params(:,3))*60*60,3) '-' num2str(max(onesigma_params(:,3))*60*60,3) '] Bq/m3/h'])
disp(['    Accumulation rate: ' num2str(best_params(4)*60*60,3) ' [' num2str(min(onesigma_params(:,4))*60*60,3) '-' num2str(max(onesigma_params(:,4))*60*60,3) '] Bq/m3/h'])
disp('----------------------')
disp('Useful information:')
data=onesigma_params(:,1);
precision=min(floor(log10(median(data))),floor(log10(range(data))));
report=round(min(max(model.instant_Rn),median(data))/10^precision)*10^precision;
disp(['    Background [Rn] level: ~' num2str(report) ' Bq/m3'])
data=onesigma_params(:,2);
precision=min(floor(log10(median(data))),floor(log10(range(data))));
report=round(min(max(model.instant_Rn),median(data))/10^precision)*10^precision;
disp(['    Maximum    [Rn] level: ~' num2str(report) ' Bq/m3'])
ventilation_time=(onesigma_params(:,2)-onesigma_params(:,1))./onesigma_params(:,3);
% disp(['    Effective ventilation time needed to flush Rn: ' num2str(floor(min(ventilation_time)/60/60)) ' to ' num2str(ceil(max(ventilation_time)/60/60)) ' hours'])
disp(['    Effective ventilation time needed to flush Rn: ~' num2str(round(max(1,median(ventilation_time)/60/60))) ' hours'])
accumulation_time=(300-onesigma_params(:,1))./onesigma_params(:,4);
if best_params(1)<300
    if best_params(2)<300
        disp(['    Safe maximum Rn concentrations.'])
    else
        % disp(['    Maximum accumulation time with safe Rn levels: ' num2str(floor(min(accumulation_time)/60/60)) ' to ' num2str(ceil(max(accumulation_time)/60/60)) ' hours'])
        disp(['    Maximum accumulation time with safe Rn levels: ~' num2str(round(max(1,median(accumulation_time)/60/60))) ' hours'])
        
    end
else
    disp(['    Unsafe minimum Rn concentrations.'])
end
%% Plot results

figure('units','normalized','outerposition',[0 0 1 1],'Name','Radon data')
set(gcf,'color','w');
hold on

seltime=~isnan(model.average_24h(1,:)'-input.Rn);
max_y_plot=max(400,max(max(input.Rn(seltime)),max(bestmodel_concentrations)));

% plot days
for n=1:numel(model.posix_time_ticks)
    text(model.posix_time_ticks(n),model.day_in_week(n)*290/7,model.time_strings{n},...
        'Color',[0.7 0.7 0.7])
end

% plot instant data
% plot(model.posix_time,model.instant_Rn,'.','Color',[0.7 0.7 0.7])


% plot input data
sel=~isnan(input.Rn);
plot(input.posix_time(sel),input.Rn(sel),'-k','LineWidth',3)
sel=find(input.Rn==max(input.Rn(seltime))&seltime,1,'first');
text(input.posix_time(sel),input.Rn(sel),'Data (24 h)',...
    'VerticalAlignment','Bottom','Color','k')

% plot model 24h
plot(input.posix_time,bestmodel_24h_average,'-m','LineWidth',2)
% plot(input.posix_time,min(model.average_24h(onesigma,:)),'-m','LineWidth',1)
% plot(input.posix_time,max(model.average_24h(onesigma,:)),'-m','LineWidth',1)
sel=find(bestmodel_24h_average==max(bestmodel_24h_average),1,'first');
text(input.posix_time(sel),bestmodel_24h_average(sel),'Model (24 h)',...
    'VerticalAlignment','Bottom','Color','m')

% plot model instant
plot(model.posix_time,bestmodel_concentrations,'-b','LineWidth',2)
% plot(model.posix_time,min(model.concentrations(onesigma,:)),'-b','LineWidth',1)
% plot(model.posix_time,max(model.concentrations(onesigma,:)),'-b','LineWidth',1)
sel=find(bestmodel_concentrations==max(bestmodel_concentrations),1,'last');
text(model.posix_time(sel),bestmodel_concentrations(sel),...
    ['Model (' num2str(median(diff(model.posix_time))/60) ' min)'],...
    'VerticalAlignment','Bottom','HorizontalAlignment','Right','Color','b')

% plot dangerous level
plot(input.posix_time,input.posix_time.*0+300,'--r','LineWidth',1)
text(mean(model.posix_time),300,'Maximum safe level',...
    'VerticalAlignment','Bottom','HorizontalAlignment','Center','Color','r')

% plot ventilation
sel=model.ventilated==1;
plot(model.posix_time(sel),model.ventilated(sel)*max_y_plot*1.1,'.b')
text(min(model.posix_time(sel)),max_y_plot*1.1,' Air circulation',...
    'VerticalAlignment','Bottom','Color','b')



xticks(model.posix_time_ticks)
xticklabels([])

yticks([0,100,200,300,600:300:max_y_plot])

xlim([min(model.posix_time) max(model.posix_time)])
ylim([0 max_y_plot*1.2])
ylabel('Rn (Bq/m^3)')
box on
grid on