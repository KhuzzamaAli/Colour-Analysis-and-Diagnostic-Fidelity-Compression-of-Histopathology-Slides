function fragile_watermark_batch()
    % ===== Step 1: Select Image Folder Interactively =====
    baseFolder = uigetdir('', 'Select Image Folder');
    if baseFolder == 0
        error('No folder was selected!');
    end

    % ???? ??? ???? ????? ??????? ???????? ??????? ??? ??? Desktop
    desktopPath = fullfile(getenv('USERPROFILE'), 'Desktop');
    outputFolder = fullfile(desktopPath, 'Tamper_Detection_Outputs');
    if ~exist(outputFolder, 'dir'), mkdir(outputFolder); end

    % ????? ?? ???? ?????
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
    fprintf('Found %d images. Running Fragile Watermark Batch Processing for %d images...\n\n', totalFound, numImages);

    % ??????? ??????? ????? ?????
    accuracy_sum = 0;
    psnr_watermarked_sum = 0;
    blockSize = 8;

    % ===== Loop Over 300 Images =====
    for imgIdx = 1:numImages
        imgPath = fullfile(allFiles(imgIdx).folder, allFiles(imgIdx).name);
        imgRGB = imread(imgPath);

        % Preprocessing & Grayscale Conversion
        if size(imgRGB, 3) == 3
            img = uint8(0.2989*double(imgRGB(:,:,1)) + 0.5870*double(imgRGB(:,:,2)) + 0.1140*double(imgRGB(:,:,3)));
        else
            img = imgRGB;
        end

        % Dimensions Check
        [H, W] = size(img);
        H = floor(H/blockSize) * blockSize;
        W = floor(W/blockSize) * blockSize;
        img = img(1:H, 1:W);

        numBlocksH = H / blockSize;
        numBlocksW = W / blockSize;

        % ===== Step 2: Fragile Watermark Insertion =====
        watermarked_img = img;
        rng(2026); % Secret Key
        watermark_key = uint8(randi([0 1], numBlocksH, numBlocksW));

        for i = 1:numBlocksH
            for j = 1:numBlocksW
                r = (i-1)*8 + 1;
                c = (j-1)*8 + 1;

                pixel_val = watermarked_img(r, c);
                bit_to_embed = watermark_key(i, j);
                watermarked_img(r, c) = bitset(pixel_val, 1, bit_to_embed);
            end
        end

        % ===== Step 3: Simulate Tampering =====
        tampered_img = watermarked_img;
        center_y = round(H/2); center_x = round(W/2);
        
        % ????? ?????? ???????? ??????? (Ground Truth Mask)
        r_min = max(1, center_y-20); r_max = min(H, center_y+20);
        c_min = max(1, center_x-20); c_max = min(W, center_x+20);
        tampered_img(r_min:r_max, c_min:c_max) = 255;

        % Ground truth tamper map at block level
        gt_tamper_map = zeros(numBlocksH, numBlocksW);
        for i = 1:numBlocksH
            for j = 1:numBlocksW
                r = (i-1)*8 + 1; c = (j-1)*8 + 1;
                if (r >= r_min && r <= r_max) || (c >= c_min && c <= c_max)
                    if any(any(tampered_img(r:r+7, c:c+7) ~= watermarked_img(r:r+7, c:c+7)))
                        gt_tamper_map(i, j) = 1;
                    end
                end
            end
        end

        % ===== Step 4: Extraction & Tamper Detection =====
        detected_tamper_map = zeros(numBlocksH, numBlocksW);
        for i = 1:numBlocksH
            for j = 1:numBlocksW
                r = (i-1)*8 + 1;
                c = (j-1)*8 + 1;

                extracted_bit = bitget(tampered_img(r, c), 1);
                expected_bit = watermark_key(i, j);

                if extracted_bit ~= expected_bit
                    detected_tamper_map(i, j) = 1;
                end
            end
        end

        % Calculate Metrics
        correct_blocks = sum(detected_tamper_map(:) == gt_tamper_map(:));
        accuracy = (correct_blocks / (numBlocksH * numBlocksW)) * 100;
        
        mse_wm = mean((double(img(:)) - double(watermarked_img(:))).^2);
        psnr_wm = (mse_wm == 0) * 99 + (mse_wm > 0) * (10 * log10((255^2) / mse_wm));

        accuracy_sum = accuracy_sum + accuracy;
        psnr_watermarked_sum = psnr_watermarked_sum + psnr_wm;

        % ??? ???? ????? ???? ???? ???
        if imgIdx == 1
            hFig = figure('Name', 'Sample Tamper Detection', 'Color', 'w', 'Visible', 'off');
            subplot(1,3,1); imshow(watermarked_img); title('Watermarked Slide');
            subplot(1,3,2); imshow(tampered_img); title('Tampered Slide');
            subplot(1,3,3); imshow(detected_tamper_map, []); title('Detected Tamper Map');
            colormap(subplot(1,3,3), jet);
            saveas(hFig, fullfile(outputFolder, 'Sample_Tamper_Detection.png'));
            close(hFig);
        end
    end

    % ???? ?????????
    avg_accuracy = accuracy_sum / numImages;
    avg_psnr_wm = psnr_watermarked_sum / numImages;

    % ===== Step 5: Print Summary Table =====
    fprintf('================ FRAGILE WATERMARK BATCH RESULTS (%d Images) ================\n', numImages);
    fprintf('Metric\t\t\t\t\t\tAverage Value\n');
    fprintf('-----------------------------------------------------------------------------\n');
    fprintf('Watermark Transparency (PSNR)\t\t%.2f dB\n', avg_psnr_wm);
    fprintf('Tamper Detection Accuracy\t\t%.2f%%\n', avg_accuracy);
    fprintf('=============================================================================\n');
    fprintf('Visual Sample and Results saved to: %s\n', outputFolder);
end