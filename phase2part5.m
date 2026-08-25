function color_compression_batch()
    % ===== Step 1: Select Main Folder Interactively =====
    baseFolder = uigetdir('', 'Select Color Image Folder');
    if baseFolder == 0
        error('No folder was selected!');
    end

    % ???? ??? ???? ????? ??????? ??? ??? Desktop
    desktopPath = fullfile(getenv('USERPROFILE'), 'Desktop');
    outputFolder = fullfile(desktopPath, 'Color_Compression_Outputs');
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
    fprintf('Found %d images. Running RGB vs YCbCr 4:2:0 Sweep for %d images...\n\n', totalFound, numImages);

    % Base Matrix & Basis DCT
    Q_base = [
        16 11 10 16 24 40 51 61; 12 12 14 19 26 58 60 55;
        14 13 16 24 40 57 69 56; 14 17 22 29 51 87 80 62;
        18 22 37 56 68 109 103 77; 24 35 55 64 81 104 113 92;
        49 64 78 87 103 121 120 101; 72 92 95 98 112 100 103 99
    ];

    C_mat = zeros(8,8);
    for i = 0:7
        for j = 0:7
            alpha = (i == 0) * sqrt(1/8) + (i > 0) * sqrt(2/8);
            C_mat(i+1, j+1) = alpha * cos((2*j + 1) * i * pi / 16);
        end
    end

    Q_levels = [20, 50, 80];
    numQ = length(Q_levels);

    % ??????? ??????? ????? ????????? ????? ?????
    bits_rgb_sum = zeros(numQ, 1);
    psnr_rgb_sum = zeros(numQ, 1);
    bits_ycbcr_sum = zeros(numQ, 1);
    psnr_ycbcr_sum = zeros(numQ, 1);
    saving_sum = zeros(numQ, 1);

    % ===== Loop Over 300 Images =====
    for imgIdx = 1:numImages
        imgPath = fullfile(allFiles(imgIdx).folder, allFiles(imgIdx).name);
        imgRGB = imread(imgPath);

        % ?????? ?? ?? ?????? ????? ?????? ??? 3 ?????
        if size(imgRGB, 3) < 3
            imgRGB = cat(3, imgRGB, imgRGB, imgRGB);
        end

        [M, N, ~] = size(imgRGB);
        M8 = floor(M/16) * 16; N8 = floor(N/16) * 16;
        imgRGB = imgRGB(1:M8, 1:N8, :);

        for idx = 1:numQ
            q_val = Q_levels(idx);

            % Scale Matrix
            S = (q_val < 50) * (5000 / q_val) + (q_val >= 50) * (200 - 2 * q_val);
            Q_scaled = max(1, floor((Q_base * S + 50) / 100));

            % --- 1. RGB Independent ---
            rec_RGB = zeros(M8, N8, 3); nz_rgb = 0;
            for c = 1:3
                ch = double(imgRGB(:,:,c)) - 128;
                q_ch = zeros(M8, N8); rec_ch = zeros(M8, N8);
                for r = 1:8:M8
                    for col = 1:8:N8
                        blk = ch(r:r+7, col:col+7);
                        q_blk = round((C_mat * blk * C_mat') ./ Q_scaled);
                        q_ch(r:r+7, col:col+7) = q_blk;
                        rec_ch(r:r+7, col:col+7) = (C_mat' * (q_blk .* Q_scaled) * C_mat) + 128;
                    end
                end
                rec_RGB(:,:,c) = rec_ch;
                nz_rgb = nz_rgb + sum(q_ch(:) ~= 0);
            end
            bits_rgb = round(nz_rgb * 4.6);
            mse_rgb = mean((double(imgRGB(:)) - double(rec_RGB(:))).^2);
            psnr_rgb = 10 * log10((255^2) / mse_rgb);

            % --- 2. YCbCr 4:2:0 Subsampled ---
            imgYCBCR = rgb2ycbcr(imgRGB);
            Y = double(imgYCBCR(:,:,1)) - 128;
            Cb_sub = imresize(double(imgYCBCR(:,:,2)), 0.5, 'bilinear') - 128;
            Cr_sub = imresize(double(imgYCBCR(:,:,3)), 0.5, 'bilinear') - 128;
            [M_sub, N_sub] = size(Cb_sub);

            % Quantize Y
            q_Y = zeros(M8, N8); rec_Y = zeros(M8, N8);
            for r = 1:8:M8
                for col = 1:8:N8
                    blk = Y(r:r+7, col:col+7);
                    q_blk = round((C_mat * blk * C_mat') ./ Q_scaled);
                    q_Y(r:r+7, col:col+7) = q_blk;
                    rec_Y(r:r+7, col:col+7) = (C_mat' * (q_blk .* Q_scaled) * C_mat) + 128;
                end
            end

            % Quantize Cb, Cr
            Q_chroma = max(1, floor((Q_scaled * 1.5)));
            q_Cb = zeros(M_sub, N_sub); rec_Cb_sub = zeros(M_sub, N_sub);
            q_Cr = zeros(M_sub, N_sub); rec_Cr_sub = zeros(M_sub, N_sub);
            for r = 1:8:M_sub
                for col = 1:8:N_sub
                    q_cb = round((C_mat * Cb_sub(r:r+7, col:col+7) * C_mat') ./ Q_chroma);
                    q_cr = round((C_mat * Cr_sub(r:r+7, col:col+7) * C_mat') ./ Q_chroma);
                    q_Cb(r:r+7, col:col+7) = q_cb;
                    q_Cr(r:r+7, col:col+7) = q_cr;
                    rec_Cb_sub(r:r+7, col:col+7) = (C_mat' * (q_cb .* Q_chroma) * C_mat) + 128;
                    rec_Cr_sub(r:r+7, col:col+7) = (C_mat' * (q_cr .* Q_chroma) * C_mat) + 128;
                end
            end

            rec_Cb = imresize(rec_Cb_sub, [M8 N8], 'bilinear');
            rec_Cr = imresize(rec_Cr_sub, [M8 N8], 'bilinear');
            rec_YCBCR = ycbcr2rgb(uint8(cat(3, min(max(rec_Y,0),255), min(max(rec_Cb,0),255), min(max(rec_Cr,0),255))));

            bits_ycbcr = round((sum(q_Y(:)~=0) + sum(q_Cb(:)~=0) + sum(q_Cr(:)~=0)) * 4.6);
            mse_ycbcr = mean((double(imgRGB(:)) - double(rec_YCBCR(:))).^2);
            psnr_ycbcr = 10 * log10((255^2) / mse_ycbcr);

            saving = ((bits_rgb - bits_ycbcr) / bits_rgb) * 100;

            % ????? ?????
            bits_rgb_sum(idx) = bits_rgb_sum(idx) + bits_rgb;
            psnr_rgb_sum(idx) = psnr_rgb_sum(idx) + psnr_rgb;
            bits_ycbcr_sum(idx) = bits_ycbcr_sum(idx) + bits_ycbcr;
            psnr_ycbcr_sum(idx) = psnr_ycbcr_sum(idx) + psnr_ycbcr;
            saving_sum(idx) = saving_sum(idx) + saving;
        end
    end

    % ???? ????????? ????????
    avg_bits_rgb = bits_rgb_sum / numImages;
    avg_psnr_rgb = psnr_rgb_sum / numImages;
    avg_bits_ycbcr = bits_ycbcr_sum / numImages;
    avg_psnr_ycbcr = psnr_ycbcr_sum / numImages;
    avg_saving = saving_sum / numImages;

    % ===== Step 2: Print Table =====
    fprintf('================ AVERAGE COLOR COMPRESSION TABLE (%d Images) ================\n', numImages);
    fprintf('Quality\tRGB bits\tRGB PSNR\tYCbCr bits\tYCbCr PSNR\tBit saving\n');
    fprintf('-----------------------------------------------------------------------------\n');
    for i = 1:numQ
        fprintf('%d\t%.0f\t\t%.2f\t\t%.0f\t\t%.2f\t\t%.1f%%\n', ...
            Q_levels(i), avg_bits_rgb(i), avg_psnr_rgb(i), avg_bits_ycbcr(i), avg_psnr_ycbcr(i), avg_saving(i));
    end
    fprintf('=============================================================================\n');

    % ===== Step 3: Bar Chart Comparison & Save =====
    hFig = figure('Name', 'RGB vs YCbCr Size', 'Color', 'w', 'Visible', 'off');
    bar_data = [avg_bits_rgb/1000, avg_bits_ycbcr/1000]; % convert to kbits
    b = bar(bar_data);
    b(1).FaceColor = [0.12, 0.47, 0.71]; % Blue
    b(2).FaceColor = [1.00, 0.50, 0.05]; % Orange
    set(gca, 'XTickLabel', {'Q=20', 'Q=50', 'Q=80'});
    ylabel('kbits');
    title(sprintf('RGB-independent vs YCbCr 4:2:0 Compressed Size (Avg of %d Images)', numImages));
    legend({'RGB-independent', 'YCbCr 4:2:0'}, 'Location', 'northwest');
    grid on;

    saveas(hFig, fullfile(outputFolder, 'RGB_vs_YCbCr_Size_Chart.png'));
    close(hFig);

    fprintf('Bar Chart saved to: %s\n', outputFolder);
end