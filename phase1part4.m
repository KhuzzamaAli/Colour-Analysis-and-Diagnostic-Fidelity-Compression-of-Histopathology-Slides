function phase1_segmentation_batch()
    % ===== Step 1: Select Main Folder Interactively =====
    baseFolder = uigetdir('', 'Select the Image Folder');
    if baseFolder == 0
        error('No folder was selected!');
    end

  
    desktop_path = fullfile(getenv('USERPROFILE'), 'Desktop');
    output_folder = fullfile(desktop_path, 'Segmentation_Outputs');
    if ~exist(output_folder, 'dir'), mkdir(output_folder); end

   
    allFiles = dir(fullfile(baseFolder, '**', '*.png'));
    if isempty(allFiles)
        allFiles = dir(fullfile(baseFolder, '**', '*.jpg'));
    end

    totalImages = length(allFiles);
    if totalImages == 0
        error('No images found in the selected folder!');
    end

    numImages = min(300, totalImages);
    fprintf('Found %d images. Processing segmentation for %d images...\n', totalImages, numImages);

    
    sample_RGB = [80, 50, 110];

    % ===== Loop Over 300 Images =====
    for i = 1:numImages
        imgPath = fullfile(allFiles(i).folder, allFiles(i).name);
        img = imread(imgPath);
        [~, fname, ~] = fileparts(allFiles(i).name);

        % ===== Step 2: Method 1 - Colour Distance-Based Segmentation =====
        imgD = double(img);
        
        % Euclidean distance
        distMap = sqrt((imgD(:,:,1) - sample_RGB(1)).^2 + ...
                       (imgD(:,:,2) - sample_RGB(2)).^2 + ...
                       (imgD(:,:,3) - sample_RGB(3)).^2);

        maxDist = max(distMap(:));
        distNorm = distMap / maxDist;
        levelDist = graythresh(distNorm);
        seg_color = distNorm < (levelDist * 0.8);
        seg_color = bwareaopen(seg_color, 20); 

        % ===== Step 3: Method 2 - Single Grey Channel (R) Segmentation =====
        greyChan = img(:,:,1); 
        levelGrey = graythresh(greyChan);
        seg_grey = greyChan < levelGrey;
        seg_grey = bwareaopen(seg_grey, 20); 

        % ===== Save Results =====
      
        imwrite(seg_color, fullfile(output_folder, [fname '_Seg_ColorMask.png']));
        
    
        imwrite(seg_grey, fullfile(output_folder, [fname '_Seg_GreyMask.png']));
        
        imwrite(uint8(distNorm * 255), fullfile(output_folder, [fname '_DistMap.png']));
    end

    fprintf('\n============================================\n');
    fprintf('Successfully processed %d images!\n', numImages);
    fprintf('Saved segmentation masks to: %s\n', output_folder);
    fprintf('============================================\n');
end