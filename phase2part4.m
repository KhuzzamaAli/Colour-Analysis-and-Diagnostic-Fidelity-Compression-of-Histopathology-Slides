function wavelet_vs_dct_batch()
    % ===== Step 1: Select Folder Interactively =====
    baseFolder = uigetdir('', 'Select Image Folder');
    if baseFolder == 0
        error('No folder was selected!');
    end

    % ???? ??? ??????? ????? ??????? ??? Desktop
    desktopPath = fullfile(getenv('USERPROFILE'), 'Desktop');
    outputFolder = fullfile(desktopPath, 'Wavelet_Outputs');
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
    fprintf('Found %d images. Running DCT vs Wavelet Sweep for %d images...\n\n', totalFound, numImages);

    Q_list = [5, 10, 20, 30, 50, 70, 90];
    numQ = length(Q_list);

    % Standard JPEG Base Matrix (for DCT calculation)
    Q_base = [
        16 11 10 16 24 40 51 61; 12 12 14 19 26 58 60 55;
        14 13 16 24 40 57 69 56; 14 17 22 29 51 87 80 62;
        18 22 37 56 68 109 103 77; 24 35 55 64 81 104 113 92;
        49 64 78 87 103 121 120 101; 72 92 95 98 112 100 103 99
    ];

    % DCT Basis Matrix
    C = zeros(8,8);
    for i = 0:7
        for j = 0:7
            alpha = (i == 0) * sqrt(1/8) + (i > 0) * sqrt(2/8);
            C(i+1, j+1) = alpha * cos((2*j + 1) * i * pi / 16);
        end
    end

    % ????????? ?????? ????????? ????? ?????
    wav_bpp_sum = zeros(numQ, 1);  wav_psnr_sum = zeros(numQ, 1);  wav_ssim_sum = zeros(numQ, 1);
    dct_bpp_sum = zeros(numQ, 1);  dct_psnr_sum = zeros(numQ, 1);

    % ===== Loop Over Images =====
    for imgIdx = 1:numImages
        imgPath = fullfile(allFiles(imgIdx).folder, allFiles(imgIdx).name);
        imgRGB = imread(imgPath);

        % Grayscale Conversion
        if size(imgRGB, 3) == 3
            img = uint8(0.2989*double(imgRGB(:,:,1)) + 0.5870*double(imgRGB(:,:,2)) + 0.1140*double(imgRGB(:,:,3)));
        else
            img = imgRGB;
        end

        [M, N] = size(img);
        M8 = floor(M/8) * 8; N8 = floor(N/8) * 8;
        imgC = double(img(1:M8, 1:N8));

        % ===== 1. Dynamic DCT Calculation =====
        imgC_dct = imgC - 128;
        for q_idx = 1:numQ
            quality = Q_list(q_idx);
            S = (quality < 50) * (5000 / quality) + (quality >= 50) * (200 - 2 * quality);
            Q_scaled = max(1, floor((Q_base * S + 50) / 100));

            dct_quant = zeros(M8, N8);
            for r = 1:8:M8
                for c = 1:8:N8
                    dct_quant(r:r+7, c:c+7) = round((C * imgC_dct(r:r+7, c:c+7) * C') ./ Q_scaled);
                end
            end

            img_rec_dct = zeros(M8, N8);
            for r = 1:8:M8
                for c = 1:8:N8
                    img_rec_dct(r:r+7, c:c+7) = C' * (dct_quant(r:r+7, c:c+7) .* Q_scaled) * C;
                end
            end
            img_rec_dct = uint8(min(max(img_rec_dct + 128, 0), 255));

            % DCT Metrics
            non_zero_dct = sum(dct_quant(:) ~= 0);
            bpp_d = (non_zero_dct * 4.6) / (M8 * N8);
            diff_d = imgC - double(img_rec_dct);
            psnr_d = 10 * log10((255^2) / mean(diff_d(:).^2));

            dct_bpp_sum(q_idx) = dct_bpp_sum(q_idx) + bpp_d;
            dct_psnr_sum(q_idx) = dct_psnr_sum(q_idx) + psnr_d;
        end

        % ===== 2. Wavelet (DWT bior4.4) Sweep =====
        [C_wav, L_wav] = wavedec2(imgC, 3, 'bior4.4');

        for q_idx = 1:numQ
            quality = Q_list(q_idx);
            thresh = 200 / quality;
            C_quant = round(C_wav / thresh) * thresh;

            img_rec_wav = waverec2(C_quant, L_wav, 'bior4.4');
            img_rec_wav = uint8(min(max(img_rec_wav, 0), 255));

            % Wavelet Metrics
            non_zero_w = sum(C_quant ~= 0);
            bpp_w = (non_zero_w * 4.2) / (M8 * N8);
            diff_w = imgC - double(img_rec_wav);
            psnr_w = 10 * log10((255^2) / mean(diff_w(:).^2));

            mu_x = mean(imgC(:)); mu_y = mean(double(img_rec_wav(:)));
            sig_x = var(imgC(:)); sig_y = var(double(img_rec_wav(:)));
            sig_xy = cov(imgC(:), double(img_rec_wav(:))); sig_xy = sig_xy(1,2);
            c1 = (0.01 * 255)^2; c2 = (0.03 * 255)^2;
            ssim_w = ((2*mu_x*mu_y + c1)*(2*sig_xy + c2)) / ((mu_x^2 + mu_y^2 + c1)*(sig_x + sig_y + c2));

            wav_bpp_sum(q_idx) = wav_bpp_sum(q_idx) + bpp_w;
            wav_psnr_sum(q_idx) = wav_psnr_sum(q_idx) + psnr_w;
            wav_ssim_sum(q_idx) = wav_ssim_sum(q_idx) + ssim_w;
        end
    end

    % ???? ?????????
    avg_dct_bpp = dct_bpp_sum / numImages;
    avg_dct_psnr = dct_psnr_sum / numImages;
    avg_wav_bpp = wav_bpp_sum / numImages;
    avg_wav_psnr = wav_psnr_sum / numImages;
    avg_wav_ssim = wav_ssim_sum / numImages;

    % ===== Step 3: Print Wavelet Table =====
    fprintf('================ AVERAGE WAVELET SWEEP RESULTS (%d Images) ================\n', numImages);
    fprintf('Quality (Q)\tbits/pixel (bpp)\tPSNR (dB)\tSSIM\n');
    fprintf('---------------------------------------------------------------------------\n');
    for i = 1:numQ
        fprintf('%d\t\t%.3f\t\t\t%.2f\t\t%.3f\n', Q_list(i), avg_wav_bpp(i), avg_wav_psnr(i), avg_wav_ssim(i));
    end
    fprintf('===========================================================================\n');

    % ===== Step 4: Plot & Save Rate-Distortion Curve =====
    hFig = figure('Name', 'Rate-Distortion: DCT vs Wavelet', 'Color', 'w', 'Visible', 'off');
    plot(avg_dct_bpp, avg_dct_psnr, '-o', 'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', 'Block-DCT (ours)');
    hold on;
    plot(avg_wav_bpp, avg_wav_psnr, '-s', 'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', 'Wavelet (pywt/DWT)');
    grid on;
    xlabel('bits per pixel (bpp)');
    ylabel('PSNR (dB)');
    title(sprintf('Rate-Distortion: DCT vs Wavelet (Average of %d Images)', numImages));
    legend('Location', 'southeast');

    % ??? ????? ???????
    saveas(hFig, fullfile(outputFolder, 'Rate_Distortion_Curve.png'));
    close(hFig);

    fprintf('Rate-Distortion Plot saved to: %s\n', outputFolder);
end