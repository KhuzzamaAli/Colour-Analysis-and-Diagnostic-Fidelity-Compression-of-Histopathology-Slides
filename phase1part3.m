function main_lab_analysis()
    % ===== Step 1: Select Main Folder Interactively =====
    baseFolder = uigetdir('', 'Select the ductal_carcinoma or BreaKHis folder');
    if baseFolder == 0
        error('No folder was selected!');
    end

    % ????? ?? ???? ??? PNG ? JPG ???? ?????? ????????? ???????
    allFiles = dir(fullfile(baseFolder, '**', '*.png'));
    if isempty(allFiles)
        allFiles = dir(fullfile(baseFolder, '**', '*.jpg'));
    end

    totalImages = length(allFiles);
    if totalImages == 0
        error('No images found in the selected folder!');
    end

    % ????? ???? ?????? ?? 300 ????
    numImages = min(300, totalImages);
    fprintf('Found %d images across patients. Processing statistics for %d images in Lab space...\n', totalImages, numImages);

    meanLAB = zeros(numImages, 3);
    patientIDs = cell(numImages, 1);

    % ===== Step 2: Compute Per-Image Statistics in L*a*b* Space =====
    for i = 1:numImages
        imgPath = fullfile(allFiles(i).folder, allFiles(i).name);
        img = im2double(imread(imgPath));

        % ??????? ?????? ?? RGB ??? CIE L*a*b* ???? ??????
        imgLab = custom_rgb_to_lab(img);

        % ???? ??????? ??? ???? (L*, a*, b*)
        for c = 1:3
            channelData = imgLab(:,:,c);
            meanLAB(i, c) = mean(channelData(:));
        end

        patientIDs{i} = allFiles(i).name(1:min(18, length(allFiles(i).name)));
    end

    % ===== Step 3: Visualization (Boxplot in L*a*b* Space) =====
    figure('Name', 'Inter-Patient Stain Variation (L*a*b*)', 'Color', 'w');

    boxplot(meanLAB, {'L* (Lightness)', 'a* (Green-Red)', 'b* (Blue-Yellow)'}, ...
        'Colors', [0.2 0.2 0.2; 0.8 0.2 0.5; 0.2 0.4 0.8], 'Symbol', 'r+');

    grid on;
    ylabel('Mean Value (L*a*b* Scale)');
    title(sprintf('Quantification of Inter-Patient Stain Variation (%d Images)', numImages));

    % ===== Step 4: Display Std-Dev Values for Table 3.1 =====
    std_L = std(meanLAB(:,1));
    std_a = std(meanLAB(:,2));
    std_b = std(meanLAB(:,3));

    fprintf('\n============================================\n');
    fprintf('Inter-Patient Std-Dev (Before Normalization):\n');
    fprintf('L* Channel Std: %.3f\n', std_L);
    fprintf('a* Channel Std: %.3f\n', std_a);
    fprintf('b* Channel Std: %.3f\n', std_b);
    fprintf('============================================\n');
end

% =========================================================================
% HELPER FUNCTIONS FOR CIE L*a*b* (From Scratch)
% =========================================================================

function lab = custom_rgb_to_lab(rgb)
    white = reshape([0.95047, 1.00000, 1.08883], 1, 1, 3);
    xyz = custom_rgb_to_xyz(rgb) ./ white;
    fx = f_func(xyz(:,:,1)); 
    fy = f_func(xyz(:,:,2)); 
    fz = f_func(xyz(:,:,3));
    lab = cat(3, 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz));
end

function xyz = custom_rgb_to_xyz(rgb)
    lin = srgb_to_linear(rgb);
    M = [0.4124564, 0.3575761, 0.1804375; ...
         0.2126729, 0.7151522, 0.0721750; ...
         0.0193339, 0.1191920, 0.9503041];
    [r, c, ch] = size(lin);
    xyz = reshape(reshape(lin, [], ch) * M', r, c, ch);
end

function lin = srgb_to_linear(c)
    lin = zeros(size(c)); 
    mask = c <= 0.04045;
    lin(mask) = c(mask) / 12.92; 
    lin(~mask) = ((c(~mask) + 0.055) / 1.055) .^ 2.4;
end

function val = f_func(t)
    delta = 6 / 29; 
    val = zeros(size(t)); 
    mask = t > delta^3;
    val(mask) = nthroot(t(mask), 3); 
    val(~mask) = t(~mask) / (3 * delta^2) + 4 / 29;
end