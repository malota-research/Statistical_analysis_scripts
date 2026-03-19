% --- Interactive Excel file selection ---
[filename, pathname] = uigetfile({'*.xlsx;*.xls', 'Excel Files (*.xlsx, *.xls)'}, 'Select Excel file with data');
if isequal(filename,0)
    disp('No file selected. Script will terminate.');
    return;
else
    fullFileName = fullfile(pathname, filename);
    fprintf('Selected file: %s\n', fullFileName);
end
% --- Load data ---
tbl = readtable(fullFileName);
% --- Rename columns to short names ---
tbl.Properties.VariableNames = {'w', 's', 'p'};
% --- Clean 's' column ---
tbl.s = string(tbl.s);
tbl.s = strip(tbl.s);
tbl.s = categorical(tbl.s);
disp('Categories after stripping and before reordercats:');
cats = cellstr(categories(tbl.s))';
disp(cats);
if ~any(strcmp(cats, 'k'))
    error('Category "k" not found in s column after cleaning. Check your data!');
end
cats(strcmp(cats,'k')) = [];
tbl.s = reordercats(tbl.s, [{'k'}, cats]);
tbl.p = categorical(tbl.p);

% --- Ask for plot and axis titles with default values ---
defaultTitleBoxplot = 'Larvae hatching success by substance group';
prompt = sprintf('Enter title for boxplot [default: %s]: ', defaultTitleBoxplot);
titleBoxplot = input(prompt, 's');
if isempty(titleBoxplot)
    titleBoxplot = defaultTitleBoxplot;
end

defaultXLabelBoxplot = 'Substance';
prompt = sprintf('Enter X-axis label for boxplot [default: %s]: ', defaultXLabelBoxplot);
xlabelBoxplot = input(prompt, 's');
if isempty(xlabelBoxplot)
    xlabelBoxplot = defaultXLabelBoxplot;
end

defaultYLabelBoxplot = 'Hatching success (0-1)';
prompt = sprintf('Enter Y-axis label for boxplot [default: %s]: ', defaultYLabelBoxplot);
ylabelBoxplot = input(prompt, 's');
if isempty(ylabelBoxplot)
    ylabelBoxplot = defaultYLabelBoxplot;
end

defaultTitleHeatmap = 'Post hoc test significance heatmap';
prompt = sprintf('Enter title for heatmap [default: %s]: ', defaultTitleHeatmap);
titleHeatmap = input(prompt, 's');
if isempty(titleHeatmap)
    titleHeatmap = defaultTitleHeatmap;
end

defaultTitleBarplot = 'Mean hatching success by substance group';
prompt = sprintf('Enter title for bar plot [default: %s]: ', defaultTitleBarplot);
titleBarplot = input(prompt, 's');
if isempty(titleBarplot)
    titleBarplot = defaultTitleBarplot;
end

defaultXLabelBarplot = 'Substance';
prompt = sprintf('Enter X-axis label for bar plot [default: %s]: ', defaultXLabelBarplot);
xlabelBarplot = input(prompt, 's');
if isempty(xlabelBarplot)
    xlabelBarplot = defaultXLabelBarplot;
end

defaultYLabelBarplot = 'Mean hatching success (0-1)';
prompt = sprintf('Enter Y-axis label for bar plot [default: %s]: ', defaultYLabelBarplot);
ylabelBarplot = input(prompt, 's');
if isempty(ylabelBarplot)
    ylabelBarplot = defaultYLabelBarplot;
end

% --- Select folder to save results ---
outputFolder = uigetdir(pwd, 'Select folder to save results');
if outputFolder == 0
    error('No output folder selected. Script will terminate.');
end
% --- Create unique folder with timestamp ---
timeStamp = datestr(now, 'yyyymmddHHMMSS');
saveFolder = fullfile(outputFolder, ['Results_', timeStamp]);
if ~exist(saveFolder, 'dir')
    mkdir(saveFolder);
end
fprintf('Results will be saved in folder: %s\n', saveFolder);

% --- Fit linear mixed-effects model ---
lme = fitlme(tbl, 'w ~ s + (1|p)');
disp(lme);
anovaResults = anova(lme);
disp(anovaResults);
coefTbl = lme.Coefficients;
levels = categories(tbl.s);
posMap = containers.Map(levels, 1:length(levels));
idx_k = find(strcmp(levels, 'k'));
idx_c60 = find(strcmp(levels, 'c60'));
idx_c70 = find(strcmp(levels, 'c70'));
num_betas = length(coefTbl.Estimate);
makeContrast = @(pos1,pos2) [0, (1:num_betas-1)==(pos1-1)] - [0, (1:num_betas-1)==(pos2-1)];
contrastList = {};
contrastNames = {};
if ~isempty(idx_c60) && ~isempty(idx_k)
    contrastList{end+1} = makeContrast(idx_c60, idx_k);
    contrastNames{end+1} = sprintf('%s vs %s', levels{idx_c60}, levels{idx_k});
end
if ~isempty(idx_c70) && ~isempty(idx_k)
    contrastList{end+1} = makeContrast(idx_c70, idx_k);
    contrastNames{end+1} = sprintf('%s vs %s', levels{idx_c70}, levels{idx_k});
end
if ~isempty(idx_c60) && ~isempty(idx_c70)
    contrastList{end+1} = makeContrast(idx_c60, idx_c70);
    contrastNames{end+1} = sprintf('%s vs %s', levels{idx_c60}, levels{idx_c70});
end
numComparisons = length(contrastList);
alpha = 0.05;
fprintf('\nPost hoc tests (all pairs) with Bonferroni correction:\n');
pVals = zeros(numComparisons,1);
for i = 1:numComparisons
    c = contrastList{i};
    [pVal, F, DF1, DF2] = coefTest(lme, c);
    pAdj = min(pVal * numComparisons, 1);
    pVals(i) = pAdj;
    signif = 'not significant';
    if pAdj < alpha
        signif = 'significant';
    end
    fprintf('%s: F(%d,%d) = %.3f, p = %.4f, adjusted p = %.4f -> %s\n', ...
        contrastNames{i}, DF1, DF2, F, pVal, pAdj, signif);
end
numLevels = length(levels);
sigMatrix = strings(numLevels);
colorMatrix = zeros(numLevels);
colorMatrix(:) = 0;
for d = 1:numLevels
    colorMatrix(d,d) = NaN;
end
for i = 1:numComparisons
    names = strsplit(contrastNames{i}, ' vs ');
    idx1 = posMap(names{1});
    idx2 = posMap(names{2});
    p = pVals(i);
    if p < 0.001
        stars = '***';
        colorMatrix(idx1, idx2) = 1;
        colorMatrix(idx2, idx1) = 1;
    elseif p < 0.01
        stars = '**';
        colorMatrix(idx1, idx2) = 1;
        colorMatrix(idx2, idx1) = 1;
    elseif p < 0.05
        stars = '*';
        colorMatrix(idx1, idx2) = 1;
        colorMatrix(idx2, idx1) = 1;
    else
        stars = '';
    end
    if ~isempty(stars)
        sigMatrix(idx1, idx2) = stars;
        sigMatrix(idx2, idx1) = stars;
    end
end

% --- Safely retrieve number of random effects ---
try
    randomEffectsTable = randomEffects(lme);
    if ismember('Group', randomEffectsTable.Properties.VariableNames)
        uniqueGroups = unique(randomEffectsTable.Group);
        numRandomEffects = numel(uniqueGroups);
    elseif ismember('Name', randomEffectsTable.Properties.VariableNames)
        uniqueNames = unique(randomEffectsTable.Name);
        numRandomEffects = numel(uniqueNames);
    else
        numRandomEffects = size(randomEffectsTable,1);
    end
catch
    numRandomEffects = 1;
end

% --- Generate plain text report ---
reportFileName = fullfile(saveFolder, ['Statistical_Analysis_Report_' timeStamp '.txt']);
fid = fopen(reportFileName, 'w');
if fid == -1
    error('Could not create report file.');
end
fprintf(fid, 'Statistical Analysis Report\n');
fprintf(fid, 'Analyzed file: %s\n', filename);
fprintf(fid, 'Date and time of analysis: %s\n\n', datestr(now));
fprintf(fid, 'Analysis of larvae hatching success for different substances:\n\n');
fprintf(fid, 'Linear mixed-effects model fitted by maximum likelihood (ML).\n');
fprintf(fid, 'Dependent variable: hatching success (w).\n');
fprintf(fid, 'Fixed effects: substance (s).\n');
fprintf(fid, 'Random effects: repetitions (p) modeled as (1|p).\n\n');
fprintf(fid, 'Interpretation of the "Intercept" coefficient:\n');
fprintf(fid, '  It is the expected value of hatching success for reference group "k".\n');
fprintf(fid, '  Other coefficients describe differences relative to this group.\n\n');
fprintf(fid, 'Model data:\n');
fprintf(fid, '  Number of observations: %d\n', lme.NumObservations);
fprintf(fid, '  Number of fixed effects: %d\n', length(lme.fixedEffects));
fprintf(fid, '  Number of random effects: %d\n', numRandomEffects);
fprintf(fid, '  Model formula: %s\n\n', char(lme.Formula));
fprintf(fid, 'Fixed effects coefficients:\n');
for i=1:height(coefTbl)
    fprintf(fid, '  %s: Estimate=%.5f, SE=%.5f, tStat=%.3f, DF=%d, p=%.4g\n', ...
        coefTbl.Name{i}, coefTbl.Estimate(i), coefTbl.SE(i), coefTbl.tStat(i), coefTbl.DF(i), coefTbl.pValue(i));
end
fprintf(fid, '\n');
fprintf(fid, 'ANOVA results:\n');
fprintf(fid, '%-20s %-10s %-10s %-10s %-15s\n', 'Term', 'FStat', 'DF1', 'DF2', 'pValue');
for r=1:height(anovaResults)
    fprintf(fid, '%-20s %-10.3f %-10d %-10d %-15.4g\n', string(anovaResults.Term(r)), anovaResults.FStat(r), anovaResults.DF1(r), anovaResults.DF2(r), anovaResults.pValue(r));
end
fprintf(fid, '\n');
fprintf(fid, 'Post hoc tests with Bonferroni correction, alpha=%.3f:\n', alpha);
for i=1:numComparisons
    fprintf(fid, '%s: Bonferroni-adjusted p = %.4g -> %s\n', contrastNames{i}, pVals(i), ternary(pVals(i)<alpha, 'significant', 'not significant'));
end
fprintf(fid, '\n');
fprintf(fid, 'Post hoc significance matrix (stars denote significance level):\n');
fprintf(fid, 'Legend: * p<0.05, ** p<0.01, *** p<0.001\n');
headerLine = sprintf('        %s\n', strjoin(levels', '     '));
fprintf(fid, headerLine);
for i=1:numLevels
    rowStr = sprintf('%s ', levels{i});
    for j=1:numLevels
        val = sigMatrix(i,j);
        if isempty(val), val=' '; end
        rowStr = [rowStr, sprintf('%4s ', val)];
    end
    fprintf(fid, '%s\n', rowStr);
end
fprintf(fid, '\n');
fprintf(fid, 'Plot descriptions:\n');
fprintf(fid, '1. Boxplot:\n   Shows distribution of hatching success by substance group, with median in red, quartiles, and individual points.\n');
fprintf(fid, '2. Heatmap:\n   Displays post hoc test significance between substance pairs; green indicates significance, stars indicate p-value levels.\n');
fprintf(fid, '\nModeling rationale:\n');
fprintf(fid, 'The linear mixed-effects model accounts for random variation among repetitions (random effect "p") and fixed effect of substance, providing reliable estimates and controlling Type I error in repeated measures.\n');
fprintf(fid, 'This report and generated plots ensure transparency and reproducibility.\n');
fclose(fid);
fprintf('Text report saved to: %s\n', reportFileName);

% --- Boxplot figure ---
figure;
boxplot(tbl.w, tbl.s, 'Symbol', '');
hBox = findobj(gca,'Tag','Box');
for j=1:length(hBox)
    set(hBox(j), 'Color', [0 0.4470 0.7410], 'LineWidth', 1.5);
end
hMedian = findobj(gca,'Tag','Median');
set(hMedian, 'Color', 'r', 'LineWidth', 2);
hWhisker = findobj(gca,'Tag','Whisker');
set(hWhisker, 'Color', 'k', 'LineWidth', 1.5);
hCap = findobj(gca,'Tag','Cap');
set(hCap, 'Color', 'k', 'LineWidth', 1.5);
hold on;
g = findgroups(tbl.s);
colors = lines(length(levels));
for i=1:length(levels)
    scatter(repmat(i,sum(g==i),1)+0.09*randn(sum(g==i),1), tbl.w(g==i), 36, colors(i,:), 'filled', 'MarkerEdgeColor', 'k', 'MarkerFaceAlpha', 0.6);
end
ylabel(ylabelBoxplot);
xlabel(xlabelBoxplot);
title(titleBoxplot);
hold off;
figNameBox = fullfile(saveFolder, ['Boxplot_' timeStamp '.png']);
saveas(gcf, figNameBox);
fprintf('Boxplot saved to %s\n', figNameBox);

% --- Heatmap figure ---
cmap = zeros(numLevels,numLevels,3);
for r=1:numLevels
    for c=1:numLevels
        if isnan(colorMatrix(r,c)), cmap(r,c,:)=[1 1 1];
        elseif colorMatrix(r,c)==1, cmap(r,c,:)=[0 0.7 0];
        else cmap(r,c,:)=[0.85 0.85 0.85];
        end
    end
end
figure;
axis square;
hold on;
for i=1:numLevels
    for j=1:numLevels
        rectangle('Position',[j-0.5 i-0.5 1 1],'FaceColor',squeeze(cmap(i,j,:))','EdgeColor','k');
    end
end
set(gca,'XTick',1:numLevels,'XTickLabel',levels,'YTick',1:numLevels,'YTickLabel',levels);
xtickangle(45);
title(titleHeatmap);
for i=1:numLevels
    for j=1:numLevels
        if sigMatrix(i,j)~=""
            text(j,i,sigMatrix(i,j),'HorizontalAlignment','center','FontSize',20,'FontWeight','bold','Color','k');
        end
    end
end
hold off;
figNameHeat = fullfile(saveFolder, ['Heatmap_' timeStamp '.png']);
saveas(gcf, figNameHeat);
fprintf('Heatmap saved to %s\n', figNameHeat);

% --- Bar plot with HSV colormap and error bars ---
figure;
meanValues = zeros(numLevels,1);
semValues = zeros(numLevels,1); % błąd standardowy średniej
for i = 1:numLevels
    groupData = tbl.w(tbl.s == levels{i});
    meanValues(i) = mean(groupData);
    semValues(i) = std(groupData)/sqrt(length(groupData));
end

barHandle = bar(meanValues);
hold on;

% Generujemy kolory HSV z równomiernym rozłożeniem
hues = linspace(0, 1, numLevels+1);
hues(end) = []; % usuwamy ostatni powtarzający się kolor
barColors = hsv(numLevels); % paleta HSV - użyje domyślnego tonu
barHandle.FaceColor = 'flat';

% Przypisujemy kolory do poszczególnych słupków
for i = 1:numLevels
    barHandle.CData(i,:) = barColors(i,:);
end

% Dodajemy wąsy błędów
errorbar(1:numLevels, meanValues, semValues, 'k', 'LineStyle', 'none', 'LineWidth', 1.5);

xlabel(xlabelBarplot);
ylabel(ylabelBarplot);
title(titleBarplot);
set(gca, 'XTickLabel', levels, 'XTick', 1:numLevels);
xtickangle(45);
hold off;

figNameBar = fullfile(saveFolder, ['Barplot_HSV_with_ErrorBars_' timeStamp '.png']);
saveas(gcf, figNameBar);
fprintf('Bar plot with HSV colors and error bars saved to %s\n', figNameBar);

% --- Residual diagnostics ---
figure;
plotResiduals(lme,'fitted');
title('Model diagnostics: Residuals vs Fitted values');
figNameResid = fullfile(saveFolder, ['Residuals_' timeStamp '.png']);
saveas(gcf, figNameResid);
fprintf('Residual diagnostics saved to %s\n', figNameResid);

% --- Helper ternary function ---
function res = ternary(cond, valTrue, valFalse)
    if cond, res=valTrue; else res=valFalse; end
end
