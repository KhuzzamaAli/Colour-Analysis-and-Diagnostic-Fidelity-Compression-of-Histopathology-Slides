function block_dct_batch()
    % ===== Step 1: Select Main Folder Interactively =====
    baseFolder = uigetdir('', 'Select Image Folder');
    if baseFolder == 0
        error('No folder was selected!');
    end

    % ???? ??? ???? Q=50 ??? ??? Desktop
    desktopPath = fullfile(getenv('USERPROFILE'), 'Desktop');
    outputFolder = fullfile(desktopPath, 'DCT_Outputs');
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
    fprintf('Found %d images. Running Block-DCT Sweep for %d images...\n\n', totalFound, numImages);

    % Standard JPEG Base Luminance Matrix
    Q_base = [
        16 11 10 16 24 40 51 61;
        12 12 14 19 26 58 60 55;
        14 13 16 24 40 57 69 56;
        14 17 22 29 51 87 80 62;
        18 22 37 56 68 109 103 77;
        24 35 55 64 81 104 113 92;
        49 64 78 87 103 121 120 101;
        72 92 95 98 112 100 103 99
    ];

    % ===== Step 2: Compute DCT Matrix C (From Scratch) =====
    C = zeros(8,8);
    for i = 0:7
        for j = 0:7
            if i == 0
                alpha = sqrt(1/8);
            else
                alpha = sqrt(2/8);
            end
            C(i+1, j+1) = alpha * cos((2*j + 1) * i * pi / 16);
        end
    end

    Q_list = [5, 10, 20, 30, 50, 70, 90];
    numQ = length(Q_list);
    
    % ??????? ??????? ????? ?????????
    bpp_sum = zeros(numQ, 1);
    psnr_sum = zeros(numQ, 1);
    ssim_sum = zeros(numQ, 1);

    % ===== Loop Over 300 Images =====
    for imgIdx = 1:numImages
        imgPath = fullfile(allFiles(imgIdx).folder, allFiles(imgIdx).name);
        imgRGB = imread(imgPath);
        [~, fname, ~] = fileparts(allFiles(imgIdx).name);

        % Grayscale conversion from scratch
        if size(imgRGB, 3) == 3
            img = uint8(0.2989*double(imgRGB(:,:,1)) + 0.5870*double(imgRGB(:,:,2)) + 0.1140*double(imgRGB(:,:,3)));
        else
            img = imgRGB;
        end

        [M, N] = size(img);
        M8 = floor(M/8) * 8;
        N8 = floor(N/8) * 8;
        imgC = double(img(1:M8, 1:N8)) - 128;
        orig_cropped = uint8(imgC + 128);

        % ===== Single Quality Reconstruction (Q = 50) for Saving =====
        quality_default = 50;
        S_def = 200 - 2 * quality_default;
        Q_scaled_def = max(1, floor((Q_base * S_def + 50) / 100));

        dct_quant_def = zeros(M8, N8);
        for r = 1:8:M8
            for c = 1:8:N8
                block = imgC(r:r+7, c:c+7);
                dct_quant_def(r:r+7, c:c+7) = round((C * block * C') ./ Q_scaled_def);
            end
        end

        img_rec_def = zeros(M8, N8);
        for r = 1:8:M8
            for c = 1:8:N8
                q_block = dct_quant_def(r:r+7, c:c+7);
                img_rec_def(r:r+7, c:c+7) = C' * (q_block .* Q_scaled_def) * C;
            end
        end
        img_rec_def = uint8(min(max(img_rec_def + 128, 0), 255));
        
        % ??? ???? ????? ?????? ?????? 50
        imwrite(img_rec_def, fullfile(outputFolder, [fname '_DCT_Q50.png']));

        % ===== Quality Factor Sweep (Q = 5 to 90) =====
        for q_idx = 1:numQ
            quality = Q_list(q_idx);

            if quality < 50
                S = 5000 / quality;
            else
                S = 200 - 2 * quality;
            end
            Q_scaled = max(1, floor((Q_base * S + 50) / 100));

            dct_quant = zeros(M8, N8);
            for r = 1:8:M8
                for c = 1:8:N8
                    block = imgC(r:r+7, c:c+7);
                    dct_quant(r:r+7, c:c+7) = round((C * block * C') ./ Q_scaled);
                end
            end

            % Decoder Reconstruction
            img_rec = zeros(M8, N8);
            for r = 1:8:M8
                for c = 1:8:N8
                    q_block = dct_quant(r:r+7, c:c+7);
                    img_rec(r:r+7, c:c+7) = C' * (q_block .* Q_scaled) * C;
                end
            end
            img_rec = uint8(min(max(img_rec + 128, 0), 255));

            % Metrics Calculation
            non_zero = sum(dct_quant(:) ~= 0);
            bpp = (non_zero * 4.6) / (M8 * N8);

            diff = double(orig_cropped) - double(img_rec);
            MSE = sum(diff(:).^2) / (M8 * N8);
            PSNR = 10 * log10((255^2) / MSE);

            mu_x = mean(double(orig_cropped(:)));
            mu_y = mean(double(img_rec(:)));
            sig_x = var(double(orig_cropped(:)));
            sig_y = var(double(img_rec(:)));
            sig_xy = cov(double(orig_cropped(:)), double(img_rec(:)));
            sig_xy = sig_xy(1,2);

            c1 = (0.01 * 255)^2; c2 = (0.03 * 255)^2;
            ssim_val = ((2*mu_x*mu_y + c1)*(2*sig_xy + c2)) / ((mu_x^2 + mu_y^2 + c1)*(sig_x + sig_y + c2));

            % ????? ????? ?????? ???????
            bpp_sum(q_idx) = bpp_sum(q_idx) + bpp;
            psnr_sum(q_idx) = psnr_sum(q_idx) + PSNR;
            ssim_sum(q_idx) = ssim_sum(q_idx) + ssim_val;
        end
    end

    % ===== Step 3: Print Average Results Table =====
    fprintf('================ AVERAGE QUALITY SWEEP RESULTS (%d Images) ================\n', numImages);
    fprintf('Quality (Q)\tbits/pixel (bpp)\tPSNR (dB)\tSSIM\n');
    fprintf('---------------------------------------------------------------------------\n');
    for i = 1:numQ
        fprintf('%d\t\t%.3f\t\t\t%.2f\t\t%.3f\n', ...
            Q_list(i), bpp_sum(i)/numImages, psnr_sum(i)/numImages, ssim_sum(i)/numImages);
    end
    fprintf('===========================================================================\n');
    fprintf('Reconstructed images (Q=50) saved to: %s\n', outputFolder);
end