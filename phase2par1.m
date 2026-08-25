function phase2_part1_redundancy_batch()
    % ===== Step 1: Select Main Folder Interactively =====
    baseFolder = uigetdir('', 'Select Image Folder');
    if baseFolder == 0
        error('No folder was selected!');
    end

    
    allFiles = dir(fullfile(baseFolder, '**', '*.png'));
    if isempty(allFiles)
        allFiles = dir(fullfile(baseFolder, '**', '*.jpg'));
    end

    totalFound = length(allFiles);
    if totalFound == 0
        error('No images found in the selected folder!');
    end


    numImages = min(300, totalFound);
    fprintf('Found %d images. Calculating Redundancy Statistics for %d images...\n\n', totalFound, numImages);

    entropyList = zeros(numImages, 1);
    codingBitsList = zeros(numImages, 1);
    codingPercentList = zeros(numImages, 1);
    spatialRedundancyList = zeros(numImages, 1);
    correlationList = zeros(numImages, 1);
    irrelevantInfoList = zeros(numImages, 1);

    % ===== Step 2: Loop Over 300 Images =====
    for k = 1:numImages
        imgPath = fullfile(allFiles(k).folder, allFiles(k).name);
        imgRGB = imread(imgPath);

        % Grey Conversion From Scratch (Y = 0.2989*R + 0.5870*G + 0.1140*B)
        if size(imgRGB, 3) == 3
            img = uint8(0.2989*double(imgRGB(:,:,1)) + 0.5870*double(imgRGB(:,:,2)) + 0.1140*double(imgRGB(:,:,3)));
        else
            img = imgRGB;
        end
        
        [M, N] = size(img);
        numPixels = M * N;

        % --- 1. Coding Redundancy (From Scratch) ---
        
        counts = zeros(1, 256);
        for val = 0:255
            counts(val + 1) = sum(img(:) == val);
        end
        p = counts / numPixels; % Probabilities

        % Entropy Calculation: H = - sum(p * log2(p))
        H = 0;
        for i = 1:256
            if p(i) > 0
                H = H - p(i) * log2(p(i));
            end
        end

        L_avg = 8; % Fixed 8-bit representation
        coding_redundancy_bits = L_avg - H;
        coding_redundancy_percent = (1 - (H / L_avg)) * 100;

        % --- 2. Spatial Redundancy (From Scratch) ---
        x = double(img(:, 1:end-1));
        y = double(img(:, 2:end));

        mean_x = sum(x(:)) / numel(x);
        mean_y = sum(y(:)) / numel(y);

        num = sum((x(:) - mean_x) .* (y(:) - mean_y));
        den = sqrt(sum((x(:) - mean_x).^2) * sum((y(:) - mean_y).^2));
        r_spatial = num / den;

        spatial_redundancy_percent = r_spatial * 100;

        % --- 3. Irrelevant Information (From Scratch) ---
        q_step = 16; % Quantization step
        img_quantized = floor(double(img) / q_step) * q_step;

        diff_img = abs(double(img) - img_quantized);
        irrelevant_pixels = sum(diff_img(:) < 8);
        irrelevant_info_percent = (irrelevant_pixels / numPixels) * 100;

        
        entropyList(k) = H;
        codingBitsList(k) = coding_redundancy_bits;
        codingPercentList(k) = coding_redundancy_percent;
        correlationList(k) = r_spatial;
        spatialRedundancyList(k) = spatial_redundancy_percent;
        irrelevantInfoList(k) = irrelevant_info_percent;
    end

    % ===== Step 3: Print Measured Numbers (Averages over 300 Images) =====
    fprintf('\n================ AVERAGE MEASURED REDUNDANCIES (%d Images) ================\n', numImages);
    fprintf('1. Coding Redundancy:\n');
    fprintf('   - Average Image Entropy (H): %.4f bits/pixel\n', mean(entropyList));
    fprintf('   - Average Bit Length (L_avg): 8 bits/pixel\n');
    fprintf('   - Redundant Coding Bits: %.4f bits/pixel (%.2f%%)\n\n', mean(codingBitsList), mean(codingPercentList));

    fprintf('2. Spatial Redundancy:\n');
    fprintf('   - Average Adjacent Pixel Correlation (r): %.4f\n', mean(correlationList));
    fprintf('   - Spatial Redundancy Measure: %.2f%%\n\n', mean(spatialRedundancyList));

    fprintf('3. Irrelevant Information:\n');
    fprintf('   - Psychovisual Redundancy (Non-essential Background): %.2f%%\n', mean(irrelevantInfoList));
    fprintf('===========================================================================\n');
end