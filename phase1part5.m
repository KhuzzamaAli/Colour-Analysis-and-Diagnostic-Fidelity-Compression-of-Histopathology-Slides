function pseudocolour_batch()
    % ===== Step 1: Select Folder Interactively =====
    baseFolder = uigetdir('', 'Select Normalised H&E Image Folder');
    if baseFolder == 0
        error('No folder was selected!');
    end

    % ???? ??? ????? ??????? ??? Desktop
    desktopPath = fullfile(getenv('USERPROFILE'), 'Desktop');
    outputFolder = fullfile(desktopPath, 'Pseudocolour_Outputs');
    if ~exist(outputFolder, 'dir'), mkdir(outputFolder); end

    % ????? ?? ???? ????? PNG ?? JPG
    allFiles = dir(fullfile(baseFolder, '**', '*.png'));
    if isempty(allFiles)
        allFiles = dir(fullfile(baseFolder, '**', '*.jpg'));
    end

    totalFound = length(allFiles);
    if totalFound == 0
        error('No images found in the selected folder!');
    end

    % ????? 300 ???? ??? ????
    numImages = min(300, totalFound);
    fprintf('Found %d images. Processing pseudocolour mapping for %d images...\n', totalFound, numImages);

    % ===== Step 2: Loop Over Images =====
    for k = 1:numImages
        imgPath = fullfile(allFiles(k).folder, allFiles(k).name);
        imgRGB = imread(imgPath);
        [~, fname, ~] = fileparts(allFiles(k).name);

        % Convert to grayscale from scratch (???? rgb2gray)
        if size(imgRGB, 3) == 3
            greyImg = uint8(0.2989*double(imgRGB(:,:,1)) + 0.5870*double(imgRGB(:,:,2)) + 0.1140*double(imgRGB(:,:,3)));
        else
            greyImg = imgRGB;
        end

        [M, N] = size(greyImg);

        % ===== Method 1: Intensity Slicing (DIP 4e Sec 6.3) =====
        slicedImg = zeros([M, N, 3], 'uint8');
        L1 = greyImg < 64;                     % Dark -> Blue
        L2 = greyImg >= 64 & greyImg < 128;    % Mid-dark -> Green
        L3 = greyImg >= 128 & greyImg < 192;   % Mid-bright -> Yellow
        L4 = greyImg >= 192;                   % Bright -> Red

        slicedImg(:,:,1) = uint8(L3*255 + L4*255); % Red Channel
        slicedImg(:,:,2) = uint8(L2*255 + L3*255); % Green Channel
        slicedImg(:,:,3) = uint8(L1*255);          % Blue Channel

        % ===== Method 2: Grey-to-Colour Transformation (Jet Map From Scratch) =====
        pseudoImg = custom_ind2rgb_jet(greyImg);

        % ===== Save Outputs =====
        imwrite(greyImg, fullfile(outputFolder, [fname '_Grayscale.png']));
        imwrite(slicedImg, fullfile(outputFolder, [fname '_IntensitySliced.png']));
        imwrite(pseudoImg, fullfile(outputFolder, [fname '_JetPseudo.png']));
    end

    fprintf('\n============================================\n');
    fprintf('Successfully processed and saved %d images!\n', numImages);
    fprintf('Output folder: %s\n', outputFolder);
    fprintf('============================================\n');
end

% =========================================================================
% HELPER FUNCTION: Custom Jet Colormap Transformation (From Scratch)
% =========================================================================
function rgb = custom_ind2rgb_jet(greyImg)
    normImg = double(greyImg) / 255;
    [rows, cols] = size(greyImg);
    rgb = zeros(rows, cols, 3, 'uint8');

    % Red Channel
    r = min(max(1.5 - abs(normImg * 4 - 3), 0), 1);
    % Green Channel
    g = min(max(1.5 - abs(normImg * 4 - 2), 0), 1);
    % Blue Channel
    b = min(max(1.5 - abs(normImg * 4 - 1), 0), 1);

    rgb(:,:,1) = uint8(r * 255);
    rgb(:,:,2) = uint8(g * 255);
    rgb(:,:,3) = uint8(b * 255);
end