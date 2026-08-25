function downstream_degradation_batch()
    % ===== Step 1: Select Folder Interactively =====
    baseFolder = uigetdir('', 'Select Image Folder');
    if baseFolder == 0
        error('No folder was selected!');
    end

    % ???? ??? ???? ????? ??????? ??? ??? Desktop
    desktopPath = fullfile(getenv('USERPROFILE'), 'Desktop');
    outputFolder = fullfile(desktopPath, 'Downstream_Task_Outputs');
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
    fprintf('Found %d images. Running Downstream Task Degradation Analysis for %d images...\n\n', totalFound, numImages);

    % Basic Segmentation Function
    segment_nuclei = @(I) imbinarize(I, graythresh(I));

    Q_levels = [5, 10, 20, 30, 50, 70, 90];
    numQ = length(Q_levels);

    % ??????? ?????? ????????? ????? ?????
    bpp_sum = zeros(numQ, 1);
    psnr_sum = zeros(numQ, 1);
    count_sum = zeros(numQ, 1);
    count_err_sum = zeros(numQ, 1);
    area_err_sum = zeros(numQ, 1);

    tempFile = tempname; % ??? ??? ???? ???

    % ===== Loop Over 300 Images =====
    for imgIdx = 1:numImages
        imgPath = fullfile(allFiles(imgIdx).folder, allFiles(imgIdx).name);
        imgRGB = imread(imgPath);

        % Ground Truth Segmentation on Original Image
        if size(imgRGB, 3) == 3
            imgGray = uint8(0.2989*double(imgRGB(:,:,1)) + 0.5870*double(imgRGB(:,:,2)) + 0.1140*double(imgRGB(:,:,3)));
        else
            imgGray = imgRGB;
        end

        bw_orig = ~segment_nuclei(imgGray);
        bw_orig = bwareaopen(bw_orig, 15); % Filter noise

        stats_orig = regionprops(bw_orig, 'Area');
        orig_count = length(stats_orig);
        orig_total_area = sum([stats_orig.Area]);

        if orig_count == 0 || orig_total_area == 0
            continue; % ???? ????? ??? ??????? ???? ?????? ??? ???
        end

        % ===== Sweep Quality Factors =====
        for i = 1:numQ
            Q = Q_levels(i);

            % ??? ???? ?? ???????/?????
            imwrite(imgRGB, tempFile, 'jpg', 'Quality', Q);
            img_rec = imread(tempFile);

            % Segment Reconstructed Image
            if size(img_rec, 3) == 3
                img_rec_gray = uint8(0.2989*double(img_rec(:,:,1)) + 0.5870*double(img_rec(:,:,2)) + 0.1140*double(img_rec(:,:,3)));
            else
                img_rec_gray = img_rec;
            end

            bw_rec = ~segment_nuclei(img_rec_gray);
            bw_rec = bwareaopen(bw_rec, 15);

            stats_rec = regionprops(bw_rec, 'Area');
            rec_count = length(stats_rec);
            rec_total_area = sum([stats_rec.Area]);

            % Absolute Error Percentages
            count_err_pct = (abs(rec_count - orig_count) / orig_count) * 100;
            area_err_pct = (abs(rec_total_area - orig_total_area) / orig_total_area) * 100;

            % Bitrate & PSNR
            file_info = dir(tempFile);
            bpp = (file_info.bytes * 8) / (size(imgRGB,1) * size(imgRGB,2));
            mse = mean((double(imgRGB(:)) - double(img_rec(:))).^2);
            psnr_val = (mse == 0) * 99 + (mse > 0) * (10 * log10((255^2) / mse));

            % ????? ?????
            bpp_sum(i) = bpp_sum(i) + bpp;
            psnr_sum(i) = psnr_sum(i) + psnr_val;
            count_sum(i) = count_sum(i) + rec_count;
            count_err_sum(i) = count_err_sum(i) + count_err_pct;
            area_err_sum(i) = area_err_sum(i) + area_err_pct;
        end
    end

    % ??? ????? ??????
    if exist(tempFile, 'file')
        delete(tempFile);
    end

    % ???? ????????? ????????
    avg_bpp = bpp_sum / numImages;
    avg_psnr = psnr_sum / numImages;
    avg_count = count_sum / numImages;
    avg_count_err = count_err_sum / numImages;
    avg_area_err = area_err_sum / numImages;

    % ===== Step 2: Print Results Table =====
    fprintf('================ AVERAGE DOWNSTREAM TASK DEGRADATION TABLE (%d Images) ================\n', numImages);
    fprintf('Quality (Q)\tbits/pixel\tPSNR (dB)\tNuclei Count\tCount Error (%%)\tArea Error (%%)\n');
    fprintf('---------------------------------------------------------------------------------------\n');
    for i = 1:numQ
        fprintf('%d\t\t%.3f\t\t%.2f\t\t%.1f\t\t%.2f%%\t\t%.2f%%\n', ...
            Q_levels(i), avg_bpp(i), avg_psnr(i), avg_count(i), avg_count_err(i), avg_area_err(i));
    end
    fprintf('================================================================-----------------------\n');

    % ===== Step 3: Plot Downstream Error Curve & Save =====
    hFig = figure('Name', 'Downstream Task Degradation', 'Color', 'w', 'Visible', 'off');
    plot(Q_levels, avg_count_err, '-o', 'LineWidth', 2, 'DisplayName', 'Nuclei Count Error (%)');
    hold on;
    plot(Q_levels, avg_area_err, '-s', 'LineWidth', 2, 'DisplayName', 'Total Nuclear Area Error (%)');
    grid on;
    xlabel('Quality Factor (Q)');
    ylabel('Segmentation Error (%)');
    title(sprintf('Downstream Task Degradation vs Quality (Avg of %d Images)', numImages));
    legend('Location', 'northeast');

    saveas(hFig, fullfile(outputFolder, 'Downstream_Degradation_Curve.png'));
    close(hFig);

    fprintf('Degradation Plot saved to: %s\n', outputFolder);
end