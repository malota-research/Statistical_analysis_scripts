% --- Wybór pliku (Excel lub CSV) ---
[filename, pathname] = uigetfile({'*.xlsx;*.xls;*.csv', 'Excel or CSV files (*.xlsx, *.xls, *.csv)'}, 'Select Muse Cytometer file');
if isequal(filename, 0)
    disp('No file selected. Exiting.');
    return;
end
fullFileName = fullfile(pathname, filename);

% --- Wczytanie pliku do komórkowej tablicy ---
[~, ~, ext] = fileparts(fullFileName);
if ismember(lower(ext), {'.xlsx', '.xls'})
    rawAll = readcell(fullFileName);
elseif strcmpi(ext, '.csv')
    fid = fopen(fullFileName, 'rt');
    rawLines = textscan(fid, '%s', 'Delimiter', '\n');
    fclose(fid);
    rawLines = rawLines{1};
    rawAll = cell(numel(rawLines), 1);
    for i = 1:numel(rawLines)
        rawAll(i) = {strsplit(rawLines{i}, ',')};
    end
    rawAll = vertcat(rawAll{:});
else
    error('Unsupported file format.');
end

% --- Usuń pierwszą kolumnę jeśli jest liczbową numeracją lub pustą ---
if isnumeric(rawAll{1,1}) || ismissing(rawAll{1,1})
    rawAll(:,1) = [];
end

% --- Pobierz pierwszy wiersz jako nagłówki ---
header1 = rawAll(1, :);

% --- Konwersja i czyszczenie nagłówków ---
for i = 1:length(header1)
    h = header1{i};
    if isempty(h) || (~ischar(h) && ~isstring(h) && ~isnumeric(h) && ~islogical(h))
        header1{i} = "";
    elseif isnumeric(h)
        header1{i} = string(h);
    else
        header1{i} = string(h);
    end
end
header1 = string(header1);

% --- Zamień puste nazwy kolumn na domyślne "Col1", "Col2", ... ---
for i = 1:length(header1)
    if strlength(strtrim(header1(i))) == 0
        header1(i) = "Col" + i;
    end
end

% --- Dane zaczynają się od drugiego wiersza ---
dataRaw = rawAll(2:end, :);

% --- Sprawdzenie zgodności liczby kolumn ---
if size(dataRaw, 2) ~= length(header1)
    error('Mismatch between number of data columns and headers.');
end

% --- Utworzenie poprawnych nazw zmiennych MATLAB ---
validNames = matlab.lang.makeValidName(header1);

% --- Funkcja do tworzenia unikalnych nazw zmiennych ---
function uniqueNames = makeUniqueNames(names)
    [~, ~, idx] = unique(names, 'stable');
    counts = accumarray(idx, 1);
    uniqueNames = names;
    occurCount = zeros(size(names));
    for i = 1:length(names)
        if counts(idx(i)) > 1
            occurCount(idx(i)) = occurCount(idx(i)) + 1;
            uniqueNames{i} = sprintf('%s_%d', names{i}, occurCount(idx(i)));
        end
    end
end

% --- Nadanie unikalnych nazw (usunięcie duplikatów) przed tworzeniem tabeli ---
validNames = makeUniqueNames(validNames);

% --- Utworzenie tabeli z danymi i poprawnymi nazwami kolumn ---
T = cell2table(dataRaw, 'VariableNames', validNames);

% --- Funkcja pytająca o konwersję kolumny ---
function tf = askConvertColumn(colName)
    question = sprintf('Czy chcesz przekonwertować kolumnę "%s" na ułamki dziesiętne? (tak/nie)', colName);
    answer = lower(input([question ' [tak/nie]: '], 's'));
    while ~ismember(answer, {'tak', 'nie', 't', 'n'})
        answer = lower(input('Proszę wpisać "tak" lub "nie": ', 's'));
    end
    tf = startsWith(answer, 't'); % true jeśli tak, false jeśli nie
end

% --- Usuń ostatni znak z wartości w kolumnie zawierającej "sample" ---
sampleColIdx = find(contains(lower(T.Properties.VariableNames), 'sample'), 1);
if ~isempty(sampleColIdx)
    sampleColName = T.Properties.VariableNames{sampleColIdx};
    colData = T.(sampleColName);
    if iscell(colData) || isstring(colData)
        sampleStr = string(colData);
        sampleStr = extractBefore(sampleStr, strlength(sampleStr)); % usuń ostatni znak
        T.(sampleColName) = sampleStr;
    else
        warning('Column "%s" is not cell/string data; skipping last-letter removal.', sampleColName);
    end
else
    warning('No column containing "sample" found; skipping last-letter removal.');
end

% --- Znajdź kolumny procentowe (według oryginalnych nagłówków) ---
percentColIdxs = find(contains(header1, '%'));

% --- Konwersja wartości procentowych na ułamki dziesiętne z pytaniem ---
for i = 1:length(percentColIdxs)
    colName = validNames{percentColIdxs(i)};
    
    if askConvertColumn(colName)
        colData = T.(colName);

        if isnumeric(colData)
            if median(colData, 'omitnan') > 1
                T.(colName) = colData / 100;
            end
        elseif iscell(colData)
            numericVals = str2double(colData);
            if all(~isnan(numericVals))
                if median(numericVals, 'omitnan') > 1
                    numericVals = numericVals / 100;
                end
                T.(colName) = numericVals;
            else
                warning('Kolumna "%s" zawiera dane nienumeryczne; pomijam konwersję.', colName);
            end
        else
            warning('Kolumna "%s" nie jest typu numeric ani cell; pomijam konwersję.', colName);
        end
    else
        fprintf('Pominięto konwersję kolumny "%s".\n', colName);
    end
end

% --- Zapis do nowego pliku Excel ---
[~, name, ~] = fileparts(filename);
newFileName = fullfile(pathname, [name '_processed.xlsx']);
writetable(T, newFileName);
fprintf('Processed data saved to: %s\n', newFileName);