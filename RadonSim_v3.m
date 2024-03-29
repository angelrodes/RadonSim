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


%% define number of models to run
n_models=3000; % at least 1000
n_random_models=round(n_models/4); % purely random
n_convergence=round(n_models/4); % expand 50% and converge to the top (best) 10% of the models
n_2s_models=n_models-n_random_models-n_convergence; % converge to ~2 sigma (see method below)
n_models=n_random_models+n_convergence+n_2s_models;
percentage_mutations=5; % percentage of parameter values that are always radomized
% mutations reduce the chance of convergence to local minimums
testing=1; % plot evolution, probabilites, etc.

%% Select files (Radon data and air circulation)

% radon_data_file='2930129618-latest.csv';
% ventilation_file='Office217.csv';

[file,path] = uigetfile('*','Radon data file');
radon_data_file=fullfile(path,file);

[file,path] = uigetfile('*','Air circulation file');
ventilation_file=fullfile(path,file);


%% read radon data
selectedfile=radon_data_file;

fid = fopen(selectedfile);

[~, Radon_data_file_name, ~] = fileparts(selectedfile);

disp(['Radon data file: ' selectedfile])

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

    % Uncertainty of the Rd values
    % assumed 10% uncertainty in the 24h average values for 200 Bq/m3 according to Airthings:
    % https://help.airthings.com/en/articles/3727185-i-have-2-monitors-beside-each-other-and-they-show-different-radon-values-how-is-that-possible
    % Avoid 1/0 and uncertainties>100%
    input.dRn=min(input.Rn,input.Rn./(input.Rn/200*100+(input.Rn==0)).^0.5);


disp(['    First data: ' num2str(input.numeric_time(1))])
disp(['    Last update: ' num2str(input.numeric_time(end))])

if min(diff(input.posix_time))<=0
    warning('Data is not in chronological order!')
end

%% read air circulation data
selectedfile=ventilation_file;

fid = fopen(selectedfile);

[~, Air_circulation_file_name, ~] = fileparts(selectedfile);

disp(['Air circulation file: ' selectedfile])

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

if min(diff(ventilation.posix_time))<=0
    warning('Data is not in chronological order!')
end

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

sel=(model.posix_time<=max(ventilation.posix_time)+1*60*60);
model.posix_time=model.posix_time(sel);
model.numeric_time=model.numeric_time(sel);

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

% create 3 hour average
model.average_3h=model.instant_Rn.*NaN;
for n=1:numel(model.instant_Rn)
    select=find(~isnan(model.instant_Rn) & abs(model.posix_time-model.posix_time(n))<3*60*60);
    if ~isempty(select)
        model.average_3h(n)=mean(model.instant_Rn(select));
    else
        model.average_3h(n)=NaN;
    end
end

% re do 24 h average
model.instant_averaged_24h=model.instant_Rn*NaN;
for n=24*60*60/median(diff(model.posix_time)):numel(model.posix_time)
    data=model.instant_Rn(model.posix_time<=model.posix_time(n) &...
        model.posix_time>model.posix_time(n)-24*60*60);
    model.instant_averaged_24h(n)=mean(data);
end


%% define parameters min_Rn max_Rn venitlation_rate accumulation_rate
range=@(x)max(x(:))-min(x(:)); % just in case RANGE is not included in your version
minimum_rates=range(model.instant_averaged_24h)/range(model.posix_time)/10;
maximum_rates=range(model.average_3h)/min(diff(model.posix_time));
minimum_Rn=min(model.average_3h(model.average_3h>0))*2;
maximum_Rn=max(model.average_3h);
% Initial parameters' limits: for the purely random, and mutant models. 
% After the purely random models, the parameters are allowed to expand 50%
% every interation, so the program can search results out of these limits.
% Structure of the limits:
% min_Rn max_Rn venitlation_rate accumulation_rate
% Br/m3 Bq/m3 Bq/m3/s Bq/m3/s
% first line = minimum values ; second line = maximum value
parameter_limits_0=[...
    10          10          minimum_rates minimum_rates ;...
    minimum_Rn maximum_Rn maximum_rates maximum_rates ...
    ];
parameter_limits=parameter_limits_0;

model.parameters=parameter_limits(1,:) .* ...
    ( parameter_limits(2,:)./parameter_limits(1,:) ).^rand(n_models,4);

model.concentrations=NaN.*zeros(n_models,numel(model.posix_time));
model.red_chi_square=NaN.*zeros(n_models,1);
model.average_24h=NaN.*zeros(n_models,numel(input.Rn));

%% run models
min_n_iterations=2; % minimum number of iterations (2 should be enough)
max_n_iterations=10; % maximum number of iterations (2 should be enough)
iteration=0;
enough_iterations=0;
while enough_iterations==0
    iteration=iteration+1;
    h = waitbar(0,'Running models...','Name',['Iteration ' num2str(iteration) ': ' num2str(n_models) ' models']);
    for n=1:n_models
        if n>1 && mod(n,10)==0
            waitbar(n/n_models,h,['n=' num2str(n) ' ; \chi^2_\nu=' num2str(min(model.red_chi_square),3)])
        end
        % recalculate parameters (convergence/expand)
        if n>n_random_models
            if n<n_random_models+n_convergence % converge and expand
                sorted_red_chi_square=sort(model.red_chi_square);
                select=model.red_chi_square<=sorted_red_chi_square(ceil(n/10)); % best 10%
                expand_limits=2; % expand
                parameter_limits=[...
                    min(model.parameters(select,:))./expand_limits ; ...
                    max(model.parameters(select,:)).*expand_limits ...
                    ];
            else % converge to "2σ"
                percentage_n_2s_models_done=(n-(n_random_models+n_convergence)+1)/n_2s_models;
                n_sigma=3*exp(-percentage_n_2s_models_done); % change this number from 3 to 1 during the fit (average~2)
                desired_min_n_fitting_models=max(round(n/100),16); % try to get at least 1% of the models in nσ
                if sum(model.red_chi_square<min(model.red_chi_square)+2)>desired_min_n_fitting_models % if enough models fit in nσ
                    select=model.red_chi_square<min(model.red_chi_square)+n_sigma;
                    parameter_limits=[...
                        min(model.parameters(select,:)) ; ...
                        max(model.parameters(select,:)) ...
                        ];
                else % if not enough models fit in nσ
                    sorted_red_chi_square=sort(model.red_chi_square);
                    select=model.red_chi_square<=sorted_red_chi_square(desired_min_n_fitting_models);
                    parameter_limits=[...
                        min(model.parameters(select,:)) ; ...
                        max(model.parameters(select,:)) ...
                        ];
                end
            end
            model.parameters(n,:)=parameter_limits(1,:) .* ...
                ( parameter_limits(2,:)./parameter_limits(1,:) ).^rand(1,4);
            if n<n_models % do not allow mutations in the last model
                % purely random (mutant) models help escaping from local minima
                mutant_parameters=parameter_limits_0(1,:) .* ...
                    ( parameter_limits_0(2,:)./parameter_limits_0(1,:) ).^rand(1,4); % mutant parameter values do not converge
                mutations=rand(1,4)<percentage_mutations/100;
                model.parameters(n,:)=model.parameters(n,:).*~mutations+mutant_parameters.*mutations;
            end
        end

        model.parameters(n,2)=min(model.parameters(n,2),max(model.instant_Rn)); % do not go over the maximum concentration measured
        model.parameters(n,1)=min(model.parameters(n,1),model.parameters(n,2)); % force min<=max
        params=model.parameters(n,:); % min_Rn max_Rn venitlation_rate accumulation_rate

        % calculate model concentrations
        for m=1:numel(model.ventilated)
            if m==1
                % concentration=params(1)*(model.ventilated(1)==1)+params(2)*(model.ventilated(1)==0);
                concentration=model.average_3h(1); % start with the first 3-h average
            elseif model.ventilated(m)==0
                concentration=concentration+params(4)*(model.posix_time(m)-model.posix_time(m-1));
            else
                concentration=concentration-params(3)*(model.posix_time(m)-model.posix_time(m-1));
            end
            concentration=max(concentration,params(1));
            concentration=min(concentration,params(2));
            model.concentrations(n,m)=concentration;
        end

        % calculate 24 h average
        Ci=model.concentrations(n,:);
        C24h=NaN.*Ci;
        for m=24*60*60/median(diff(model.posix_time)):round(30*60/median(diff(model.posix_time))):numel(model.posix_time)
            data=Ci(model.posix_time<=model.posix_time(m) &...
                model.posix_time>model.posix_time(m)-24*60*60);
            C24h(m)=mean(data);
        end
        %     interpolate 24 h average
        sel=~isnan(C24h);
        model.average_24h(n,:)=interp1(model.posix_time(sel),C24h(sel),input.posix_time);

        % calculate reduced chi square (goodness of fit of the model)
        select=~isnan(model.average_24h(n,:)'-input.Rn);
        dof=sum(select)-4;
        % Reduced chi-square
        model.red_chi_square(n,1)=sum((model.average_24h(n,select)'-input.Rn(select)).^2./(input.dRn(select)).^2)/dof;
    end
    close(h)
    % decide if doing another iteration
    if iteration>=max_n_iterations
        enough_iterations=1;
    end
    if iteration>=min_n_iterations
        if sum(model.red_chi_square<min(model.red_chi_square)+1)>min(100,max(round(n_models/100),30)) % target between 30 and 100 fitting models
            enough_iterations=1;
        end
    end
end

%% select best result
% calculate best and one-sigma range
select=find(model.red_chi_square==min(model.red_chi_square),1,'first');
best_fit=select;
best_params=model.parameters(select,:); % min_Rn max_Rn venitlation_rate accumulation_rate
bestmodel_concentrations=model.concentrations(select,:);
bestmodel_24h_average=model.average_24h(select,:);

onesigma=(model.red_chi_square<min(model.red_chi_square)+1);
minimum_models_in_one_sigma=min(30,round(n_models/100));
enogh_one_sigma_models=1;
if sum(onesigma)<minimum_models_in_one_sigma % if there are not many models in one-sigma, just take more
    sortedchi=sort(model.red_chi_square);
    maxchi=sortedchi(minimum_models_in_one_sigma+1);
    onesigma= (model.red_chi_square<maxchi);
    enogh_one_sigma_models=0;
else
    maxchi=min(model.red_chi_square)+1;
end
onesigma_params=model.parameters(onesigma,:);
onesigma_red_chi_square=model.red_chi_square(onesigma);

chisqpdf=@(x,dof)1./(2.^(dof/2)*gamma(dof/2)).*x.^(dof/2).*exp(-x/2);
model.probabilities=chisqpdf(model.red_chi_square,1); % this is > 0 even with very low GOF
model.one_sigma_prob=chisqpdf(maxchi,1);




%% display results
disp('----------------------')
disp(['Place: ' Air_circulation_file_name])
disp('Best-fit results, (median), and [one sigma range]:')
disp(['    Reduced chi-squared: '  num2str(round(min(model.red_chi_square)*10)/10) ...
    ' (' num2str(round(median(model.red_chi_square(onesigma))*10)/10) ')'...
    ' [' num2str(round(min(model.red_chi_square)*10)/10) '-' num2str(round(maxchi*10)/10) ']'])
% check if we have enough models
if sum(onesigma)>=min(30,n_models/100)
    disp(['    N models in 1-sigma: ' num2str(sum(onesigma)) ' of ' num2str(n_models)])
else
    warning(['N models in 1-sigma: only ' num2str(sum(onesigma)) ' of ' num2str(n_models)])
end
if ~enogh_one_sigma_models
    warning(['Not eonugh models below min(reduced-chi-squared)+1. Please run more models for better uncertainties.'])
end
% check if model fits the data
if max(onesigma_params(:,1))>min(onesigma_params(:,2)) % if max and min Rn overlap or inverted
    disp('----------------------')
    warning('Apparently, model does not fit the data!')
    disp('Air circulation does not reduce Rn levels significantly.')
    sel=~isnan(model.average_3h);
    data=model.average_3h(sel);
    precis=ceil(log10(mean(data)))-floor(log10(std(data)/numel(unique(data))));
    disp(['Average and SDOM [Rn] = ' num2str(mean(data),precis) ' ± ' num2str(std(data)/numel(unique(data)),1) ' Bq/m3'])
end
% check if model fits the data
if max(onesigma_params(:,1))>min(onesigma_params(:,2)) % if max and min Rn overlap or inverted
    disp('----------------------')
    warning('Apparently, model does not fit the data!')
    disp('Air circulation does not reduce Rn levels significantly.')
    sel=~isnan(model.average_3h);
    data=model.average_3h(sel);
    precis=ceil(log10(mean(data)))-floor(log10(std(data)/numel(unique(data))));
    disp(['Average and SDOM [Rn] = ' num2str(mean(data),precis) ' ± ' num2str(std(data)/numel(unique(data)),1) ' Bq/m3'])
end
disp(['    [Rn]min: ' num2str(best_params(1),3)  ...
    ' (' num2str(median(onesigma_params(:,1)),3) ')'...
    ' [' num2str(min(onesigma_params(:,1)),3) '-' num2str(max(onesigma_params(:,1)),3) '] Bq/m3'])
disp(['    [Rn]max: ' num2str(best_params(2),3) ...
    ' (' num2str(median(onesigma_params(:,2)),3) ')'...
    ' [' num2str(min(onesigma_params(:,2)),3) '-' num2str(max(onesigma_params(:,2)),3) '] Bq/m3'])
disp(['    Ventilation  rate: ' num2str(best_params(3)*60*60,3) ...
    ' (' num2str(median(onesigma_params(:,3))*60*60,3) ')'...
    ' [' num2str(min(onesigma_params(:,3))*60*60,3) '-' num2str(max(onesigma_params(:,3))*60*60,3) '] Bq/m3/h'])
disp(['    Accumulation rate: ' num2str(best_params(4)*60*60,3) ...
    ' (' num2str(median(onesigma_params(:,4))*60*60,3) ')'...
    ' [' num2str(min(onesigma_params(:,4))*60*60,3) '-' num2str(max(onesigma_params(:,4))*60*60,3) '] Bq/m3/h'])
disp('----------------------')
disp('Useful information:')
% levels
data=max(best_params(:,1),median(onesigma_params(:,1))); % be conservative between best fit and median of one_sigma
% precision=max(0,min(floor(log10(median(data))),floor(log10(range(data))))-1);
precision=2;
report=round(min(max(model.instant_Rn),median(data))/10^precision)*10^precision;
disp(['    Background [Rn] level: ' '~' num2str(report) ' Bq/m3'])
data=max(best_params(:,2),median(onesigma_params(:,2)));
% precision=max(0,min(floor(log10(median(data))),floor(log10(range(data))))-1);
precision=2;
report=round(min(max(model.instant_Rn),median(data))/10^precision)*10^precision;
disp(['    Maximum    [Rn] level: ' '~' num2str(report) ' Bq/m3'])

disp(['Recommendations for ' Air_circulation_file_name ':'])

if median(onesigma_params(:,1))>300 || median(best_params(:,1))>300
    disp(['    Unsafe minimum Rn concentrations.'])
    warning('Do not use this room!')
elseif median(onesigma_params(:,2))<300 && median(best_params(:,2))<300
    disp(['    Safe radon levels.'])
else
    initial_ventilation_time1=(best_params(:,2)-best_params(:,1))./best_params(:,3)+60*60*24*2*(best_params(:,1)>300);
    initial_ventilation_time2=median((onesigma_params(:,2)-onesigma_params(:,1))./onesigma_params(:,3)+60*60*24*2*(onesigma_params(:,1)>300));
    data=max(initial_ventilation_time1,initial_ventilation_time2);
    if median(data)<60*120
        report_string=[num2str(ceil(median(data)/60/5)*5) ' minutes'];
    elseif median(data)>60*60*24
        report_string='all the time';
    else
        report_string=[num2str(round(median(data)/60/60)) ' hours'];
    end
    disp(['    Initial ventilation time needed to flush Rn: ~' report_string '.'])

    accumulation_time1=(300-best_params(:,1))./best_params(:,4);
    ventilation_time1=(300-best_params(:,1))./best_params(:,3);
    ventilation_ratio1=ventilation_time1./accumulation_time1;
    accumulation_time2=(300-onesigma_params(:,1))./onesigma_params(:,4);
    ventilation_time2=(300-onesigma_params(:,1))./onesigma_params(:,3);
    ventilation_ratio2=ventilation_time2./accumulation_time2;
    accumulation_time=min(accumulation_time1,accumulation_time2);
    ventilation_ratio=max(ventilation_ratio1,ventilation_ratio2);
    hours_between_ventilations=ceil(median(accumulation_time/60/60));
    ventilation_minutes=ceil(median(ventilation_ratio)*hours_between_ventilations/60);
    
    if ventilation_minutes/60>0.9*hours_between_ventilations
        disp('    Please, keep the room ventilated as much as possible!')
    else
        disp(['    Then, to keep safe radon levels: ventilate the room for ~' ...
            num2str(ceil(ventilation_minutes/5)*5) ...
            ' minutes every ~' ...
            num2str(hours_between_ventilations) ...
            ' hours.'])
    end

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
        'Color',[0.6 0.6 0.6])
end

% plot instant data
% plot(model.posix_time,model.instant_Rn,'-','Color',[0.9 0.9 0.9])

% plot 3h average
plot(model.posix_time,model.average_3h,'-','Color',[0.9 0.9 0.9])
sel=find(model.average_3h==min(model.average_3h),1,'first');
text(model.posix_time(sel),model.average_3h(sel),...
    ' 3h-average',...
    'VerticalAlignment','Bottom','Color',[0.8 0.8 0.8])

% plot input data
sel=~isnan(input.Rn);
plot(input.posix_time(sel),input.Rn(sel),'-k','LineWidth',3)
sel=find(input.Rn==max(input.Rn(seltime))&seltime,1,'first');
text(input.posix_time(sel),input.Rn(sel),'Data (24 h)',...
    'VerticalAlignment','Bottom','Color','k')


% plot 5-min model
if testing==1 % plot uncertainties
    thismodel_concentrations=max(model.concentrations(onesigma,:));
    plot(model.posix_time,thismodel_concentrations,'--b','LineWidth',1)
    thismodel_concentrations=min(model.concentrations(onesigma,:));
    plot(model.posix_time,thismodel_concentrations,'--b','LineWidth',1)
end
plot(model.posix_time,bestmodel_concentrations,'-b','LineWidth',2)
sel=find(bestmodel_concentrations==max(bestmodel_concentrations),1,'last');
text(model.posix_time(sel),bestmodel_concentrations(sel),...
    ['Model (' num2str(median(diff(model.posix_time))/60) ' min)'],...
    'VerticalAlignment','Bottom','HorizontalAlignment','Right','Color','b')

% plot model 24h
if testing==1 % plot uncertainties
    thismodel_24h_average=max(model.average_24h(onesigma,:));
    plot(input.posix_time,thismodel_24h_average,':m','LineWidth',1)
    thismodel_24h_average=min(model.average_24h(onesigma,:));
    plot(input.posix_time,thismodel_24h_average,':m','LineWidth',1)
    % plot(input.posix_time,lastmodel,'*m','LineWidth',1) % last data tested
end
plot(input.posix_time,bestmodel_24h_average,'-m','LineWidth',2)
sel=find(bestmodel_24h_average==max(bestmodel_24h_average),1,'first');
text(input.posix_time(sel),bestmodel_24h_average(sel),'Model (24 h)',...
    'VerticalAlignment','Bottom','Color','m')

% plot dangerous level
plot(input.posix_time,input.posix_time.*0+300,'--r','LineWidth',1)
% text(mean(model.posix_time),300,'Maximum safe level',...
%     'VerticalAlignment','Bottom','HorizontalAlignment','Center','Color','r')
text(min(model.posix_time),300,'Maximum safe level',...
    'VerticalAlignment','Bottom','HorizontalAlignment','Left','Color','r')

% plot ventilation
sel=model.ventilated==0;
plot(model.posix_time(sel),~model.ventilated(sel)*max_y_plot*1.1,'.','Color',[0.9 0.9 0.9])
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

title(strrep(Air_circulation_file_name, '_', ' '))
box on
grid on

%% testing plots

if testing==1
    %% plot parameter evolution and distribution
    figure('units','normalized','outerposition',[0 1 0.5 0.5],'Name','Parameters')
    subplot(1,2,1); hold on; box on
    plot(1:numel(model.red_chi_square),model.red_chi_square,'.b')
    plot(1:numel(model.red_chi_square),model.parameters(:,1),'.','Color',[0.8 0.8 0.8])
    plot(1:numel(model.red_chi_square),model.parameters(:,2),'.','Color',[0.5 0.5 0.3])
    plot(1:numel(model.red_chi_square),model.parameters(:,3)*60*60,'.r')
    plot(1:numel(model.red_chi_square),model.parameters(:,4)*60*60,'.g')
    set(gca, 'YScale', 'log')
    xlabel('model'); legend('\chi^2_\nu','minRn (Bq/m3)','maxRn (Bq/m3)','vent. (Bq/m3/h)','accum (Bq/m3/h)')

    % plot parameter distribution 
    subplot(1,2,2); hold on; box on
    plot([min(min(model.parameters)) max(max(model.parameters*60*60))],model.one_sigma_prob*[1 1],':k')
    plot(model.parameters(:,1),model.probabilities,'.','Color',[0.8 0.8 0.8])
    plot(model.parameters(:,2),model.probabilities,'.','Color',[0.5 0.5 0.3])
    plot(model.parameters(:,3)*60*60,model.probabilities,'.r')
    plot(model.parameters(:,4)*60*60,model.probabilities,'.g')
    set(gca, 'XScale', 'log'); ylim([0 model.one_sigma_prob*3])
    ylabel('P(\chi^2_\nu)'); legend('\chi^2_\nu+1','minRn (Bq/m3)','maxRn (Bq/m3)','vent. (Bq/m3/h)','accum (Bq/m3/h)')
    grid on

    %% plot instant model histograms (testing)
    figure('units','normalized','outerposition',[1 0 0.5 0.5],'Name','Concentrations')
    subplot(2,1,1)
    data=model.instant_Rn;
    hold on; box on
    step_hist=round(max(50,min(300,max(data)/30))/50)*50;
    v=step_hist/2:step_hist:max(data);
    hist(data,v)
    yLimits = get(gca,'YLim');
    maxYValue = yLimits(2);
    plot(300*[1,1],[0,maxYValue],'--r')
    xlabel('1-h concentration (Bq/m3)');
    title(strrep(Air_circulation_file_name, '_', ' '))

    % 3-h
    subplot(2,1,2)
    data=model.average_3h;
    hold on; box on
    step_hist=round(max(50,min(300,max(data)/30))/50)*50;
    v=step_hist/2:step_hist:max(data);
    hist(data,v)
    yLimits = get(gca,'YLim');
    maxYValue = yLimits(2);
    plot(300*[1,1],[0,maxYValue],'--r')
    xlabel('3-h concentration (Bq/m3)');

    %% Ventilation and measurements plot (Spanish, no model)
    figure('units','normalized','outerposition',[0 0 0.5 0.5],'Name','Datos Radón')
    set(gcf,'color','w');
    hold on

    seltime=~isnan(model.average_24h(1,:)'-input.Rn);
    max_y_plot=max(400,max(max(input.Rn(seltime)),max(bestmodel_concentrations)));

    % plot days
    for n=1:numel(model.posix_time_ticks)
        text(model.posix_time_ticks(n),model.day_in_week(n)*290/7,model.time_strings{n},...
            'Color',[0.4 0.4 0.4])
    end

    % plot instant data
    % plot(model.posix_time,model.instant_Rn,'-','Color',[0.9 0.9 0.9])

    % plot 3h average
    sel=model.posix_time>min(ventilation.posix_time)+1.5*60*60;
    plot(model.posix_time(sel),model.average_3h(sel),'-','Color','k')
    sel=find(model.average_3h==max(model.average_3h),1,'first');
    text(model.posix_time(sel),model.average_3h(sel),...
        ' Media 3-h (calculado)',...
        'VerticalAlignment','top','Color','k')

    % plot input data
    sel=~isnan(input.Rn) & input.posix_time>min(ventilation.posix_time)+24*60*60;
    plot(input.posix_time(sel),input.Rn(sel),'-k','LineWidth',3)
    sel=find(input.Rn==max(input.Rn(seltime))&seltime,1,'first');
    text(input.posix_time(sel),input.Rn(sel),...
        ' Media 24-h (datos originales)',...
        'FontWeight', 'bold',...
        'VerticalAlignment','Bottom','Color','k')

    % plot dangerous level
    plot(input.posix_time,input.posix_time.*0+300,'--r','LineWidth',1)
    % text(mean(model.posix_time),300,'Maximum safe level',...
    %     'VerticalAlignment','Bottom','HorizontalAlignment','Center','Color','r')
    text(min(model.posix_time),300,' Límite de seguridad',...
        'VerticalAlignment','Bottom','HorizontalAlignment','Left','Color','r')

    % plot ventilation
    y_position=max_y_plot*1.15;
    sel=model.ventilated==0;
    plot(model.posix_time(sel),~model.ventilated(sel)*y_position,'.','Color',[0.9 0.9 0.9])
    sel=model.ventilated==1;
    plot(model.posix_time(sel),model.ventilated(sel)*y_position,'.b')
    text(min(model.posix_time(sel)),y_position,...
        ' Ventana abierta',...
        'VerticalAlignment','Bottom','Color','b')

    xticks(model.posix_time_ticks)
    xticklabels([])

    yticks([0,100,200,300,600:300:max_y_plot*1.5])

    xlim([min(model.posix_time) max(model.posix_time)])
    ylim([0 max_y_plot*1.25])
    ylabel('Rn (Bq/m^3)')

    title(strrep(Air_circulation_file_name, '_', ' '))
    box on
    grid on
end