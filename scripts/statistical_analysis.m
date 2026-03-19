clc;
clear;
%% --- Load data ---
[file, path] = uigetfile({'*.xlsx;*.xls;*.csv', 'Excel or CSV (*.xlsx, *.xls, *.csv)'}, 'Select data file');
if isequal(file,0)
    error('No file selected!');
end
fullFileName = fullfile(path,file);
[~,~,ext] = fileparts(fullFileName);
switch lower(ext)
    case {'.xlsx','.xls'}
        T = readtable(fullFileName);
    case '.csv'
        T = readtable(fullFileName);
    otherwise
        error('Unsupported file format.');
end
%% --- Select output folder ---
outputFolder = uigetdir(path, 'Select folder for saving results');
if outputFolder == 0
    error('No output folder selected.');
end
%% --- Timestamp for unique filenames ---
timeStamp = datestr(now, 'yyyymmddHHMMSS');
%% --- Check SampleID column ---
if ~ismember('SampleID', T.Properties.VariableNames)
    error('Column "SampleID" is missing in data!');
end
%% --- Convert SampleID to string and count repeats ---
T.SampleID = string(T.SampleID);
[uniqueGroups, ~, groupIdx] = unique(T.SampleID);
repeatCounts = zeros(height(T),1);
for i = 1:length(uniqueGroups)
    idxInGroup = find(groupIdx == i);
    repeatCounts(idxInGroup) = 1:length(idxInGroup);
end
T.RepeatNumber = repeatCounts;
%% --- Interactive group and parameter selection ---
[groupIdxSelected, tfGroup] = listdlg('PromptString','Select groups for analysis:', ...
    'SelectionMode','multiple', 'ListString', uniqueGroups, 'Name','Group selection');
if ~tfGroup || isempty(groupIdxSelected)
    error('No groups selected for analysis.');
end
selectedGroups = uniqueGroups(groupIdxSelected);
paramList = setdiff(T.Properties.VariableNames, {'SampleID','RepeatNumber'}, 'stable');
disp('Dostępne aktualne nazwy parametrów z pliku:');
disp(paramList);
[paramIdxSelected, tfParam] = listdlg('PromptString','Select parameters for analysis:', ...
    'SelectionMode','multiple', 'ListString', paramList, 'Name','Parameter selection');
if ~tfParam || isempty(paramIdxSelected)
    error('No parameters selected for analysis.');
end
selectedParameters = paramList(paramIdxSelected);
fprintf('Selected groups:\n'); disp(selectedGroups);
fprintf('Selected parameters:\n'); disp(selectedParameters);
%% --- Filter data ---
dataIdx = ismember(T.SampleID, selectedGroups);
T_filtered = T(dataIdx,:);
%% --- Prepare report file ---
reportFileName = [erase(file, ext) '_analysis_report_' timeStamp '.txt'];
txtReportFileName = fullfile(outputFolder, reportFileName);
fid = fopen(txtReportFileName, 'w');
if fid == -1
    error('Cannot create report text file');
end
fprintf(fid, 'Statistical analysis report of cytometry results\n');
fprintf(fid, 'Data file: %s\n\n', file);
alpha = 0.05;
%% --- Groups colors ---
numGroups = numel(selectedGroups);
colorMap = hsv(numGroups);
%% --- Analysis and plots ---
for p = 1:numel(selectedParameters)
    param = selectedParameters{p};
    fprintf(fid, '--- Analysis of parameter: %s ---\n', char(param));
    disp(['Analysis of parameter: ', char(param)]);
    valsAll = [];
    groupLabels = [];
    normFlags = [];
    normPvalues = zeros(numGroups,1);
    resultsParam = struct;
    for g = 1:numGroups
        group = selectedGroups(g);
        valsRaw = T_filtered.(param)(T_filtered.SampleID == group);
        vals = cleanNumericData(valsRaw);
        if isempty(vals)
            warning('No data: %s, group: %s', param, group);
            fprintf(fid, 'Group: %s - no data.\n', char(group));
            normPvalues(g) = NaN;
            continue;
        end
        try
            [hNorm, pNorm] = adtest(vals, 'Alpha', alpha);
        catch
            warning('Normality test not performed for %s in group %s', param, group);
            hNorm = 1; pNorm = NaN;
        end
        meanVal = mean(vals);
        SE = std(vals)/sqrt(length(vals));
        medianVal = median(vals);
        q25 = quantile(vals, 0.25);
        q75 = quantile(vals, 0.75);
        outStr = sprintf('Group: %s, n=%d, Distribution: %s, Mean=%.3g, SE=%.3g, Median=%.3g, Q25=%.3g, Q75=%.3g, Normality test p=%.4g\n', ...
            char(group), length(vals), ternary(hNorm==0, 'normal', 'non-normal'), ...
            meanVal, SE, medianVal, q25, q75, pNorm);
        fprintf(fid, '%s', outStr);
        fprintf(outStr);
        valsAll = [valsAll; vals];
        groupLabels = [groupLabels; repmat(string(group), length(vals), 1)];
        normFlags = [normFlags; hNorm == 0];
        normPvalues(g) = pNorm;
        resultsParam.(char(group)) = struct('vals', vals, 'hNorm', hNorm, 'pNorm', pNorm,...
            'mean', meanVal, 'SE', SE, 'median', medianVal, 'q25', q25, 'q75', q75);
    end
    allNormal = all(normFlags);
    % Write normality test summary with p-values to report
    fprintf(fid, '\nNormality test (Anderson-Darling) p-values by group:\n');
    for g = 1:numGroups
        fprintf(fid, '  %s: p=%.4g\n', char(selectedGroups(g)), normPvalues(g));
    end
    if numGroups == 1
        fprintf(fid,'Analysis requires at least 2 groups - only one selected.\n');
        disp('Analysis requires at least 2 groups - only one selected.');
        continue;
    end
    % Check homogeneity of variances (Levene’s test) if all normal
    varianceHomogeneous = true;
    pLevene = NaN;
    if numGroups > 1 && allNormal
        groupDataForLevene = [];
        groupLabelsForLevene = [];
        for g = 1:numGroups
            vals = resultsParam.(char(selectedGroups(g))).vals;
            groupDataForLevene = [groupDataForLevene; vals];
            groupLabelsForLevene = [groupLabelsForLevene; repmat(string(selectedGroups(g)), length(vals), 1)];
        end
        try
            pLevene = vartestn(groupDataForLevene, groupLabelsForLevene, 'TestType', 'LeveneAbsolute', 'Display', 'off');
            varianceHomogeneous = pLevene >= alpha;
            fprintf(fid, '\nLevene''s test for homogeneity of variances: p=%.4g, %s\n', pLevene, ternary(varianceHomogeneous, 'homogeneous', 'heterogeneous'));
        catch
            varianceHomogeneous = NaN;
            fprintf(fid, '\nLevene''s test for homogeneity of variances could not be performed.\n');
        end
    else
        fprintf(fid, '\nLevene''s test for homogeneity of variances: Not performed (normality not met or single group).\n');
    end
    significantPairs = [];
    pMatrix = nan(numGroups);
    if numGroups == 2
        vals1 = resultsParam.(char(selectedGroups(1))).vals;
        vals2 = resultsParam.(char(selectedGroups(2))).vals;
        if allNormal
            [hTest, pVal] = ttest2(vals1, vals2, 'Alpha', alpha);
            fprintf(fid, '\nStudent''s t-test (%s vs %s): p=%.4f, %s\n', char(selectedGroups(1)), char(selectedGroups(2)), pVal, ternary(hTest, 'significant', 'not significant'));
            fprintf(fid, 'Test rationale: Two groups with normal distribution; parametric Student''s t-test applied.\n');
        else
            pVal = ranksum(vals1, vals2);
            fprintf(fid, '\nMann-Whitney test (%s vs %s): p=%.4f, %s\n', char(selectedGroups(1)), char(selectedGroups(2)), pVal, ternary(pVal < alpha, 'significant', 'not significant'));
            fprintf(fid, 'Test rationale: At least one group lacks normal distribution; nonparametric Mann-Whitney test applied.\n');
        end
        pMatrix(1,2) = pVal; pMatrix(2,1) = pVal;
        if pVal < alpha
            significantPairs = [significantPairs; 1 2 pVal];
        end
    else
        if allNormal && varianceHomogeneous
            [pA, ~, stats] = anova1(valsAll, groupLabels, 'off');
            fprintf(fid, '\nOne-way ANOVA: p=%.4f, %s\n', pA, ternary(pA < alpha, 'significant', 'not significant'));
            fprintf(fid, 'Test rationale: Multiple groups with normal distribution and homogeneous variance; parametric ANOVA applied.\n');
            if pA < alpha
                fprintf(fid, 'Post hoc Tukey HSD test:\n');
                c = multcompare(stats, 'Display', 'off');
                for iC = 1:size(c,1)
                    g1 = c(iC,1);
                    g2 = c(iC,2);
                    pVal = c(iC,6);
                    fprintf(fid, '  %s vs %s: p=%.4g, %s\n', char(selectedGroups(g1)), char(selectedGroups(g2)), pVal, ternary(pVal < alpha, 'significant', 'not significant'));
                    pMatrix(g1,g2) = pVal; pMatrix(g2,g1) = pVal;
                    if pVal < alpha
                        significantPairs = [significantPairs; g1 g2 pVal];
                    end
                end
                fprintf(fid, 'Post hoc rationale: Tukey HSD test performed due to significant ANOVA results.\n');
            end
        else
            pK = kruskalwallis(valsAll, groupLabels, 'off');
            fprintf(fid, '\nKruskal-Wallis test: p=%.4f, %s\n', pK, ternary(pK < alpha, 'significant', 'not significant'));
            fprintf(fid, 'Test rationale: Multiple groups with non-normal distribution or heterogeneous variance; nonparametric Kruskal-Wallis test applied.\n');
            if pK < alpha
                fprintf(fid, 'Post hoc Dunn test:\n');
                c = unique(groupLabels);
                nGroups = length(c);
                groupData = cell(nGroups, 1);
                for i = 1:nGroups
                    groupData{i} = valsAll(groupLabels == c(i));
                end
                allData = vertcat(groupData{:});
                ranks = tiedrank(allData);
                idxStart = 1;
                groupRanks = cell(nGroups, 1);
                for i = 1:nGroups
                    n = length(groupData{i});
                    groupRanks{i} = ranks(idxStart:idxStart+n-1);
                    idxStart = idxStart + n;
                end
                nSamples = cellfun(@numel, groupData);
                N = sum(nSamples);
                for i = 1:nGroups-1
                    for j = i+1:nGroups
                        R1 = mean(groupRanks{i});
                        R2 = mean(groupRanks{j});
                        ni = nSamples(i);
                        nj = nSamples(j);
                        SE = sqrt((N*(N+1))/12*(1/ni + 1/nj));
                        z = abs(R1 - R2)/SE;
                        pValDunn = 2*(1 - normcdf(z));
                        signif = ternary(pValDunn < alpha, 'significant', 'not significant');
                        fprintf(fid, '  %s vs %s: p=%.4f (%s)\n', char(c(i)), char(c(j)), pValDunn, signif);
                        g1idx = find(selectedGroups == c(i));
                        g2idx = find(selectedGroups == c(j));
                        pMatrix(g1idx,g2idx) = pValDunn; pMatrix(g2idx,g1idx) = pValDunn;
                        if pValDunn < alpha
                            significantPairs = [significantPairs; g1idx g2idx pValDunn];
                        end
                    end
                end
                fprintf(fid, 'Post hoc rationale: Dunn''s post hoc test used after significant Kruskal-Wallis due to non-normality.\n');
            end
        end
    end
    
    % Prepare matrices for heatmaps (significance and levels)
    levelsMatrix = nan(numGroups);
    sigMatrix = nan(numGroups);
    for i = 1:numGroups
        for j = 1:numGroups
            pVal = pMatrix(i,j);
            if isnan(pVal)
                levelsMatrix(i,j) = NaN;
                sigMatrix(i,j) = NaN;
            elseif pVal < 0.001
                levelsMatrix(i,j) = 3;
                sigMatrix(i,j) = 1;
            elseif pVal < 0.01
                levelsMatrix(i,j) = 2;
                sigMatrix(i,j) = 1;
            elseif pVal < 0.05
                levelsMatrix(i,j) = 1;
                sigMatrix(i,j) = 1;
            else
                levelsMatrix(i,j) = 0;
                sigMatrix(i,j) = 0;
            end
        end
    end
    
    % Prepare data for plots
    meansPlot = zeros(numGroups,1);
    SEsPlot = zeros(numGroups,1);
    valsAllPlot = [];
    groupLabelsPlot = [];
    for g = 1:numGroups
        valsRaw = T_filtered.(param)(T_filtered.SampleID == selectedGroups(g));
        vals = cleanNumericData(valsRaw);
        meansPlot(g) = mean(vals);
        SEsPlot(g) = std(vals)/sqrt(length(vals));
        valsAllPlot = [valsAllPlot; vals];
        groupLabelsPlot = [groupLabelsPlot; repmat(string(selectedGroups(g)), length(vals),1)];
    end
  
    % Interactive plot titles and axis labels input
    defaultTitleBox = ['Boxplot - ' char(param)];
    plotTitleBox = input(['Enter boxplot title (default: ' defaultTitleBox '): '],'s');
    if isempty(plotTitleBox), plotTitleBox = defaultTitleBox; end
    xLabelBox = input('Enter X-axis label for boxplot (default: Groups): ','s');
    if isempty(xLabelBox), xLabelBox = 'Groups'; end
    yLabelBox = input(['Enter Y-axis label for boxplot (default: ' char(param) '): '],'s');
    if isempty(yLabelBox), yLabelBox = char(param); end

    figure('Visible','off','Position',[100,100,700,400]);
    boxplot(valsAllPlot, groupLabelsPlot);
    title(plotTitleBox, 'Interpreter', 'none');
    xlabel(xLabelBox, 'Interpreter', 'none');
    ylabel(yLabelBox, 'Interpreter', 'none');
    grid on;
    saveas(gcf, fullfile(outputFolder, ['boxplot_' char(param) '_' timeStamp '.png']));
    close(gcf);

    % Barplot with error bars
    defaultTitleBar = ['Barplot - ' char(param)];
    plotTitleBar = input(['Enter barplot title (default: ' defaultTitleBar '): '],'s');
    if isempty(plotTitleBar), plotTitleBar = defaultTitleBar; end
    xLabelBar = input('Enter X-axis label for barplot (default: Groups): ','s');
    if isempty(xLabelBar), xLabelBar = 'Groups'; end
    yLabelBar = input(['Enter Y-axis label for barplot (default: ' char(param) '): '],'s');
    if isempty(yLabelBar), yLabelBar = char(param); end

    figure('Visible','off','Position',[100,100,700,400]);
    b = bar(categorical(selectedGroups), meansPlot, 'FaceColor', 'flat');
    for k = 1:numGroups
        b.CData(k,:) = colorMap(k,:);
    end
    hold on;
    errorbar(1:numGroups, meansPlot, SEsPlot, 'k', 'LineStyle', 'none', 'LineWidth', 1.5);
    hold off;
    xlabel(xLabelBar, 'Interpreter', 'none');
    ylabel(yLabelBar, 'Interpreter', 'none');
    title(plotTitleBar, 'Interpreter', 'none');
    grid on;
    saveas(gcf, fullfile(outputFolder, ['barplot_' char(param) '_' timeStamp '.png']));
    close(gcf);

    % Heatmap binary
    cmapSig = [0.7 0.7 0.7; 0 0.6 0];
    nanColor = [1 1 1];
    figure('Visible','off','Position',[100,100,600,600]);
    imagesc(sigMatrix);
    colormap(cmapSig);
    caxis([0 1]);
    ax = gca;
    ax.XTick = 1:numGroups;
    ax.YTick = 1:numGroups;
    ax.XTickLabel = selectedGroups;
    ax.YTickLabel = selectedGroups;
    ax.YTickLabel = selectedGroups;   % identyczna kolejność jak na osi x
    ax.YDir = 'normal';                % oś y bez odwrócenia kolejności
    ax.XTickLabelRotation = 45;
    ax.FontSize = 12;
    ax.FontWeight = 'bold';
    ax.LineWidth = 1;
    hold on;
    for k = 1:numGroups
        rectangle('Position',[k-0.5,k-0.5,1,1],'FaceColor',nanColor,'EdgeColor','none');
    end
    for k = 0:numGroups
        plot([0.5 numGroups+0.5],[k+0.5 k+0.5],'k-','LineWidth',1);
        plot([k+0.5 k+0.5],[0.5 numGroups+0.5],'k-','LineWidth',1);
    end
    hold off;
    saveas(gcf, fullfile(outputFolder, ['significance_binary_heatmap_' char(param) '_' timeStamp '.png']));
    close(gcf);

    % Heatmap stars
    figure('Visible','off','Position',[100,100,600,600]);
    imagesc(levelsMatrix);
    colormap([cmapSig(1,:); cmapSig(2,:); cmapSig(2,:); cmapSig(2,:)]);
    colorbar('off');
    ax = gca;
    ax.XTick = 1:numGroups;
    ax.YTick = 1:numGroups;
    ax.XTickLabel = selectedGroups;
    ax.YTickLabel = selectedGroups;
    ax.YTickLabel = selectedGroups;   % identyczna kolejność jak na osi x
    ax.YDir = 'normal';                % oś y bez odwrócenia kolejności
    ax.XTickLabelRotation = 45;
    ax.FontSize = 12;
    ax.FontWeight = 'bold';
    ax.LineWidth = 1;
    hold on;
    for k = 1:numGroups
        rectangle('Position',[k-0.5,k-0.5,1,1],'FaceColor',nanColor,'EdgeColor','none');
    end
    for k = 0:numGroups
        plot([0.5 numGroups+0.5],[k+0.5 k+0.5],'k-','LineWidth',1);
        plot([k+0.5 k+0.5],[0.5 numGroups+0.5],'k-','LineWidth',1);
    end
    for ix = 1:numGroups
        for iy = 1:numGroups
            switch levelsMatrix(iy, ix)
                case 1, starTxt = '*';
                case 2, starTxt = '**';
                case 3, starTxt = '***';
                otherwise, starTxt = '';
            end
            if ~isempty(starTxt)
                text(ix, iy, starTxt, 'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
                    'FontSize',20,'FontWeight','bold','Color','k');
            end
        end
    end
    hold off;
    saveas(gcf, fullfile(outputFolder, ['significance_stars_heatmap_' char(param) '_' timeStamp '.png']));
    close(gcf);

    % Add plot descriptions in report
    fprintf(fid, '\n--- Plot descriptions for parameter: %s ---\n', char(param));
    fprintf(fid, '\n[Boxplot]\nDisplays distribution of parameter "%s" values by groups, including median, quartiles, and outliers.\n', char(param));
    fprintf(fid, '\n[Barplot]\nShows mean values of parameter "%s" in groups with standard errors; compares group means.\n', char(param));
    fprintf(fid, '\n[Binary significance heatmap]\nHighlights significant pairwise differences in green; gray indicates non-significant; white on diagonal.\n');
    fprintf(fid, '\n[Significance stars heatmap]\nStars indicate significance (* p < 0.05, ** p < 0.01, *** p < 0.001).\n\n');
end
fprintf(fid, '\nEnd of report.\n');
fclose(fid);
fprintf('Text report saved to:\n%s\n', txtReportFileName);

% Ask if to generate cumulative percentage stacked bar chart
defaultTitle = 'Cumulative Percentage Stacked Bar Chart of Cell Cycle Phases';
answer = questdlg('Do you want to generate a cumulative percentage stacked bar chart?', 'Stacked Bar Chart', 'Yes', 'No', 'No');
if strcmp(answer, 'Yes')
    % Select parameters for stacked bar chart
    [selIdx, tf] = listdlg('PromptString', 'Select parameters for stacked chart (% phases):', ...
        'ListString', selectedParameters, 'SelectionMode', 'multiple');
    if tf && ~isempty(selIdx)
        chosenParams = selectedParameters(selIdx);
        
        % Ask for plot title with a default suggestion
        titlePlot = input(['Enter plot title (default: ', defaultTitle, '): '], 's');
        if isempty(titlePlot)
            titlePlot = defaultTitle;
        end
        % Ask for X and Y axis labels
        xLabelPlot = input('Enter X-axis label (default: Groups): ', 's');
        if isempty(xLabelPlot)
            xLabelPlot = 'Groups';
        end
        yLabelPlot = input('Enter Y-axis label (default: Percentage [%]): ', 's');
        if isempty(yLabelPlot)
            yLabelPlot = 'Percentage [%]';
        end
        
        % Ask user for custom legend names with default being parameter names
        legendNames = strings(size(chosenParams));
        for i = 1:length(chosenParams)
            promptStr = ['Enter legend name for "', chosenParams{i}, '" (default: ', chosenParams{i}, '): '];
            userInput = input(promptStr, 's');
            if isempty(userInput)
                legendNames(i) = chosenParams{i};
            else
                legendNames(i) = userInput;
            end
        end
        
        % Prepare data matrix: rows = groups, columns = chosen parameters
        dataMatrix = zeros(numGroups, length(chosenParams));
        for k = 1:length(chosenParams)
            param = chosenParams{k};
            for g = 1:numGroups
                valsRaw = T_filtered.(param)(T_filtered.SampleID == selectedGroups(g));
                vals = cleanNumericData(valsRaw);
                dataMatrix(g, k) = mean(vals);
            end
        end
        
        % Normalize rows to sum to 100%
        rowSums = sum(dataMatrix, 2);
        dataPercent = dataMatrix ./ rowSums * 100;
        
        % Plot stacked bar chart with legend below
        figure('Position', [100, 100, 900, 500]);
        barHandle = bar(dataPercent, 'stacked');
        xticks(1:numGroups);
        xticklabels(selectedGroups);
        xtickangle(45);
        xlabel(xLabelPlot, 'Interpreter', 'none');
        ylabel(yLabelPlot, 'Interpreter', 'none');
        title(titlePlot, 'Interpreter', 'none');
        grid on;
        
        % Add legend with names provided, place it below the plot horizontally
        lgd = legend(legendNames, 'Location', 'southoutside', 'Orientation', 'horizontal');
        % Adjust legend box to not overlap
        lgd.Box = 'on';
        
        % Ask for folder to save the chart
        folderSave = uigetdir(outputFolder, 'Select folder to save stacked bar chart');
        if folderSave ~= 0
            saveas(gcf, fullfile(folderSave, ['cumulative_percentage_stacked_chart_' timeStamp '.png']));
            fprintf('Stacked bar chart saved to: %s\n', folderSave);
        else
            fprintf('Chart not saved - no folder selected.\n');
        end
        
        close(gcf);
    else
        disp('No parameters selected for stacked bar chart.');
    end
end

%% --- Helper functions ---
function valsClean = cleanNumericData(valsRaw)
    if iscell(valsRaw)
        valsNum = str2double(valsRaw);
    elseif isstring(valsRaw) || ischar(valsRaw)
        valsNum = str2double(cellstr(valsRaw));
    else
        valsNum = valsRaw;
    end
    valsClean = valsNum(~isnan(valsNum));
end
function res = ternary(cond, valTrue, valFalse)
    if cond, res=valTrue; else res=valFalse; end
end
