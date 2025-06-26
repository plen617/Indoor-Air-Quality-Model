% Define meal time ranges (24-hour format)
breakfast_start = 7;
breakfast_end = 9;
lunch_start = 11;
lunch_end = 13;
dinner_start = 17;
dinner_end = 19;

% Meal duration distributions (normalized)              %   %    %    %
%                                                       % make sure these are reflected ; can extend past the meal time boundaries!
prob_breakfast_duration = [155, 45, 58, 36, 20, 2, 1, 0, 0, 0] / 372;
prob_lunch_duration = [231, 13, 26, 16, 12, 5, 2, 0, 0, 0] / 372;
prob_dinner_duration = [56, 8, 35, 42, 86, 46, 23, 14, 1, 0] / 372;

% Stove usage frequency distributions
prob_breakfast_usage = [0.1983, 0.4164, 0.1537, 0.0945, 0.1568];
prob_lunch_usage = [0.2929, 0.5284, 0.1395, 0.0254];
prob_dinner_usage = [0.00817, 0.0877, 0.266, 0.398];

% Function to sample meal duration
function duration = sample_duration(probabilities, durations)
    r = rand();
    cumulative_prob = 0;
    for i = 1:length(probabilities)
        cumulative_prob = cumulative_prob + probabilities(i);
        if r <= cumulative_prob
            duration = durations(i);
            return;
        end
    end
    duration = durations(end);
end

% Function to sample stove usage frequency
function usage_days = sample_stove_usage(prob)
    rand_num = rand();
    if rand_num < prob(1)
        usage_days = 0;
    elseif rand_num < prob(1) + prob(2)
        usage_days = 1 + round(rand());
    elseif rand_num < prob(1) + prob(2) + prob(3)
        usage_days = 3 + round(rand());
    elseif rand_num < prob(1) + prob(2) + prob(3) + prob(4)
        usage_days = 5 + round(rand());
    else
        usage_days = 7;
    end
end

% Simulation setup
num_days = 30;
num_weeks = num_days / 7;
stove_usage = zeros(num_days, 24);
stove_durations = zeros(num_days, 24);
stove_type_matrix = zeros(num_days, 24);
meal_durations = [0, 3, 8, 13, 20, 38, 53, 76, 105, 150];

for week = 1:num_weeks
    week_start = (week - 1) * 7 + 1;
    for meal_idx = 1:3
        if meal_idx == 1
            usage_days = sample_stove_usage(prob_breakfast_usage);
            prob_duration = prob_breakfast_duration;
        elseif meal_idx == 2
            usage_days = sample_stove_usage(prob_lunch_usage);
            prob_duration = prob_lunch_duration;
        else
            usage_days = sample_stove_usage(prob_dinner_usage);
            prob_duration = prob_dinner_duration;
        end

        days_used = randperm(7, usage_days);
        for i = 1:length(days_used)
            day_idx = week_start + days_used(i) - 1;
            for hour = 0:23
                if (hour >= breakfast_start && hour < breakfast_end && meal_idx == 1) || ...
                   (hour >= lunch_start && hour < lunch_end && meal_idx == 2) || ...
                   (hour >= dinner_start && hour < dinner_end && meal_idx == 3)
                    stove_usage(day_idx, hour+1) = 1;
                    stove_durations(day_idx, hour+1) = sample_duration(prob_duration, meal_durations) / 60;
                end
            end
        end
    end
end

% Emissions setup
year = 1;
pct_elect = [0.35];
pct_nat = [0.85];
hourly_emissions = zeros(num_days, 24);

for day = 1:num_days
    for hour = 1:24
        if stove_usage(day, hour) == 1
            stove_type_rand = rand();
            if stove_type_rand < pct_elect(year)
                ER_stoven = 1.1e3;
                stove_type_matrix(day, hour) = 1;
            elseif stove_type_rand < pct_nat(year)
                ER_stoven = 3.8e3;
                stove_type_matrix(day, hour) = 2;
            else
                ER_stoven = 1.2e3;
                stove_type_matrix(day, hour) = 3;
            end
            hourly_emissions(day, hour) = ER_stoven * stove_durations(day, hour);
        end
    end
end

% Compute hourly steady-state concentrations
C_ss_hourly = zeros(num_days, 24);
for day = 1:num_days
    for hour = 1:24
        E = hourly_emissions(day, hour);
        a_inf = 0.5;
        a_nat = 0.2;
        P = 0.8;
        C0 = 10;
        house_vol = 250;
        k_dep = 0.3;
        C_ss_hourly(day, hour) = ((a_inf*P + a_nat)*C0 + E/house_vol) / (a_inf + k_dep);
    end
end

% Create timestamp vector
startDate = datetime('today');
timestamps = startDate + hours(0:(num_days*24 - 1));

% Flatten for table
stove_usage_flat = reshape(stove_usage', [], 1);
stove_durations_flat = reshape(stove_durations', [], 1);
stove_type_flat = reshape(stove_type_matrix', [], 1);
emissions_flat = reshape(hourly_emissions', [], 1);
C_ss_flat = reshape(C_ss_hourly', [], 1);

% Create results table
results_table = table(...
    timestamps', ...
    stove_usage_flat, ...
    stove_durations_flat, ...
    stove_type_flat, ...
    emissions_flat, ...
    C_ss_flat, ...
    'VariableNames', {'Timestamp', 'StoveUsage', 'StoveDuration_hr', 'StoveType', 'Emissions_ug_hr', 'C_ss_ug_m3'});

% Display sample
disp(results_table(1:10, :))

% Plot
figure;
subplot(2, 1, 1);
plot(results_table.Timestamp, results_table.Emissions_ug_hr, 'LineWidth', 1.5);
xlabel('Time');
ylabel('Emissions (\mu g/hr)');
title('Hourly Emissions Over 30 Days');
grid on;

subplot(2, 1, 2);
plot(results_table.Timestamp, results_table.C_ss_ug_m3, 'LineWidth', 1.5);
xlabel('Time');
ylabel('C_{ss} (\mu g/m^3)');
title('Hourly Steady-State Concentration Over 30 Days');
grid on;

% Create C_ss report table
report_rows = num_days * 24;
C_ss_report = table('Size', [report_rows, 14], ...
    'VariableTypes', ["datetime", "double", "double", "double", "double", ...
                      "double", "double", "double", "double", "double", ...
                      "double", "double", "double", "double"], ...
    'VariableNames', {'Datetime', 'Day', 'Hour', 'StoveType', 'StoveDuration_hr', ...
                      'EmissionRate_ug_per_hr', 'E_ug', 'a_inf', 'a_nat', 'P', ...
                      'C0', 'Volume', 'k_dep', 'C_ss'});

% Populate report
C_ss_datetimes = startDate + hours(0:(report_rows - 1))';
idx = 1;
for day = 1:num_days
    for hour = 1:24
        stove_type = stove_type_matrix(day, hour);
        stove_duration = stove_durations(day, hour);
        if stove_type == 1
            ER_stoven = 1.1e4;
        elseif stove_type == 2
            ER_stoven = 3.8e4;
        elseif stove_type == 3
            ER_stoven = 1.2e4;
        else
            ER_stoven = 0;
        end
        E = ER_stoven * stove_duration;
        C_ss = ((a_inf*P + a_nat)*C0 + E/house_vol) / (a_inf + k_dep);

        C_ss_report.Datetime(idx) = C_ss_datetimes(idx);
        C_ss_report.Day(idx) = day;
        C_ss_report.Hour(idx) = hour - 1;
        C_ss_report.StoveType(idx) = stove_type;
        C_ss_report.StoveDuration_hr(idx) = stove_duration;
        C_ss_report.EmissionRate_ug_per_hr(idx) = ER_stoven;
        C_ss_report.E_ug(idx) = E;
        C_ss_report.a_inf(idx) = a_inf;
        C_ss_report.a_nat(idx) = a_nat;
        C_ss_report.P(idx) = P;
        C_ss_report.C0(idx) = C0;
        C_ss_report.Volume(idx) = house_vol;
        C_ss_report.k_dep(idx) = k_dep;
        C_ss_report.C_ss(idx) = C_ss;

        idx = idx + 1;
    end
end

% Save report to CSV
writetable(C_ss_report, 'C_ss_verification_report.csv');
disp('✅ C_ss + Emissions report saved to C_ss_verification_report.csv');

% Precompute daily values
daily_emissions = sum(hourly_emissions, 2);                    % ug/day
daily_avg_C_ss = mean(C_ss_hourly, 2);                         % ug/m^3
daily_stove_hours = sum(stove_durations, 2);                   % hr/day

% Flatten stove types and count usage
used_stove_types = stove_type_flat(stove_type_flat > 0);
stove_type_labels = {'Electric', 'Natural Gas', 'Propane'};
stove_type_counts = [sum(used_stove_types == 1), ...
                     sum(used_stove_types == 2), ...
                     sum(used_stove_types == 3)];

% Generate time vector for days
day_vector = startDate + days(0:num_days-1);

% Create figure
figure;

subplot(2,2,1);
bar(day_vector, daily_emissions, 'FaceColor', [0.2 0.6 0.8]);
xlabel('Day');
ylabel('Emissions (\mug)');
title('Daily Total Emissions');
grid on;

subplot(2,2,2);
bar(day_vector, daily_avg_C_ss, 'FaceColor', [0.9 0.5 0.3]);
xlabel('Day');
ylabel('Average C_{ss} (\mug/m^3)');
title('Daily Avg. Steady-State Concentration');
grid on;

subplot(2,2,3);
bar(day_vector, daily_stove_hours, 'FaceColor', [0.4 0.7 0.5]);
xlabel('Day');
ylabel('Stove Usage (hr)');
title('Daily Total Stove Usage Duration');
grid on;

subplot(2,2,4);
bar(categorical(stove_type_labels), stove_type_counts, 'FaceColor', [0.7 0.4 0.9]);
ylabel('Frequency');
title('Stove Type Usage Count');
grid on;


% --- Choose the day to visualize (1 to 30) ---
day_to_plot = 5;

% --- Extract hourly data for that day ---
hours = 0:23;
emissions_day = hourly_emissions(day_to_plot, :);
C_ss_day = C_ss_hourly(day_to_plot, :);

% --- Create a time axis for labeling ---
day_time_axis = datetime(startDate + days(day_to_plot - 1)) + hours(hours);

% --- Plot emissions and C_ss for the selected day ---
figure;
yyaxis left;
plot(day_time_axis, emissions_day, '-o', 'LineWidth', 2);
ylabel('Emissions (\mug/hr)');
ylim([0, max(emissions_day)*1.1]);

yyaxis right;
plot(day_time_axis, C_ss_day, '-s', 'LineWidth', 2);
ylabel('C_{ss} (\mug/m^3)');
ylim([0, max(C_ss_day)*1.1]);

title(['Emissions and C_{ss} for Day ', num2str(day_to_plot)]);
xlabel('Hour');
grid on;
legend('Emissions', 'C_{ss}', 'Location', 'best');
