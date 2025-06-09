

%% read reflectance in 30m scale  landsat 8/9  band 2 3 4 5 10
Landsat_Band_input=readgeoraster('Landsat89_Bands_2_3_4_5_10_2019-07-24.tif'); 
Landsat_Band_input=Landsat_Band_input(1:end-1,:,:);

%% read reflectance in 10m scale  sentinel-2  band 2 3 4 8
Sentinel_Band_Refl=readgeoraster('Sentinel2_Bands_2_3_4_8_2019-07-24.tif'); 
Sentinel_Band_Refl=Sentinel_Band_Refl(1:end-2,:,:);

%% classification type, 3-7 test
class_type=5; 
input_date1=Sentinel_Band_Refl;
[m, n, d] = size(input_date1); image_reshaped = reshape(input_date1, m*n, d); image_reshaped=double(image_reshaped );
[clusterIdx, clusterCenters] = kmeans(image_reshaped, class_type, 'MaxIter', 1000); classified_image = reshape(clusterIdx, m, n); 

%% produce 30m-scale pure pixels in S2 resolution (3*10m X 3*10m)
Landcover_classif_10m = classified_image; [rows, cols] = size(Landcover_classif_10m); Landcover_classif_10m_new = zeros(rows, cols); 
num_30m_rows = floor(rows / 3); num_30m_cols = floor(cols / 3);
[i_indices, j_indices] = meshgrid(1:num_30m_rows, 1:num_30m_cols);  i_indices = (i_indices(:) - 1) * 3 + 1; j_indices = (j_indices(:) - 1) * 3 + 1;
for idx = 1:length(i_indices)
    i = i_indices(idx);    j = j_indices(idx);
    block = Landcover_classif_10m(i:i+2, j:j+2);
    if isscalar(unique(block))
        Landcover_classif_10m_new(i:i+2, j:j+2) = block;
    end
end

%% produce pure landcover data in 30m scale
[rows, cols] = size(Landcover_classif_10m_new); out_rows = rows / 3; out_cols = cols / 3;
Landcover_30m_pure = zeros(out_rows, out_cols); Landcover_30m_pure = Landcover_classif_10m_new(1:3:end, 1:3:end);

%% read reflectance in 30m scale  landsat 8/9  band 2 3 4 5 10
Landsat_Band2_Refl=double(Landsat_Band_input(:,:,1)); Landsat_Band3_Refl=double(Landsat_Band_input(:,:,2));
Landsat_Band4_Refl=double(Landsat_Band_input(:,:,3)); Landsat_Band5_Refl=double(Landsat_Band_input(:,:,4)); 
Landsat_Band10_Temp=double(Landsat_Band_input(:,:,5));

%% read reflectance in 10m scale  sentinel-2  band 2 3 4 8
Sentinel_Band2_Refl=double(Sentinel_Band_Refl(:,:,1)); Sentinel_Band3_Refl=double(Sentinel_Band_Refl(:,:,2));
Sentinel_Band4_Refl=double(Sentinel_Band_Refl(:,:,3)); Sentinel_Band8_Refl=double(Sentinel_Band_Refl(:,:,4));

%% upscale sentinel-2 matrix to same column-row as landsat 8/9, for pure pixels searching
mean3x3 = @(block_struct) mean(block_struct.data(:));
Sentinel_Band2_Refl_upscale = blockproc(Sentinel_Band2_Refl, [3 3], mean3x3);
Sentinel_Band3_Refl_upscale = blockproc(Sentinel_Band3_Refl, [3 3], mean3x3);
Sentinel_Band4_Refl_upscale = blockproc(Sentinel_Band4_Refl, [3 3], mean3x3);
Sentinel_Band8_Refl_upscale = blockproc(Sentinel_Band8_Refl, [3 3], mean3x3);

%% loop %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
window_size = 131;  half_length_2 = (window_size-1)/2;
max_time = 2;
hiddenLayerSize = [10, 10]; trainFcn = 'trainlm';

[rows, cols] = size(Landcover_classif_10m); 
Landsat_Like_Temp_10m_trans = zeros(rows, cols, class_type);

i_range = 301:2100; % Set the range to count total points
j_range = 301:2100; % 301:2100

input_size_ref=4;
output_size_ref=4;
output_size_temp=1;

for mm = 1:class_type 
    count_mask = (Landcover_classif_10m(i_range, j_range) == mm);
    totalPoints = sum(count_mask(:));
    
    Landcover_type_30m = Landcover_30m_pure;  % Creates a mask for the current category
    Landcover_type_30m(Landcover_type_30m ~= mm) = NaN;   Landcover_type_30m = Landcover_type_30m/mm;

    sentinel_upscale_bands = zeros(size(Sentinel_Band2_Refl_upscale, 1), size(Sentinel_Band2_Refl_upscale, 2), 4);
    sentinel_upscale_bands(:,:,1) = Sentinel_Band2_Refl_upscale .* Landcover_type_30m;
    sentinel_upscale_bands(:,:,2) = Sentinel_Band3_Refl_upscale .* Landcover_type_30m;
    sentinel_upscale_bands(:,:,3) = Sentinel_Band4_Refl_upscale .* Landcover_type_30m;
    sentinel_upscale_bands(:,:,4) = Sentinel_Band8_Refl_upscale .* Landcover_type_30m;
    
    landsat_ref_bands = zeros(size(Landsat_Band2_Refl, 1), size(Landsat_Band2_Refl, 2), 4);
    landsat_ref_bands(:,:,1) = Landsat_Band2_Refl .* Landcover_type_30m;
    landsat_ref_bands(:,:,2) = Landsat_Band3_Refl .* Landcover_type_30m;
    landsat_ref_bands(:,:,3) = Landsat_Band4_Refl .* Landcover_type_30m;
    landsat_ref_bands(:,:,4) = Landsat_Band5_Refl .* Landcover_type_30m;
    
    Landsat_Band10_Temp_LCmm = Landsat_Band10_Temp .* Landcover_type_30m;
    
    progressTracker = initializeProgressWithClass(mm, totalPoints); % Initializes the progress system with category display
    
    parfor i = 301:2100 % i_range
        for j = 301:2100 % j_range
            try
                if Landcover_classif_10m(i,j) == mm
                    l = floor((i-1)/3)+1;  m = floor((j-1)/3)+1; % Calculate the corresponding 30m resolution coordinates
                   
                    [input_x, output_t] = processWindow3(sentinel_upscale_bands, landsat_ref_bands, l, m, half_length_2); % Processing reflectance bands
                    
                    net_ref = configureNetwork(input_size_ref, output_size_ref, trainFcn, hiddenLayerSize);  % Train the reflectivity network
                    PredResult = zeros(4,1);
                    for kk = 1:max_time
                        net_ref = train(net_ref, input_x, output_t);
                        Pred_input = [Sentinel_Band2_Refl(i,j), Sentinel_Band3_Refl(i,j), Sentinel_Band4_Refl(i,j), Sentinel_Band8_Refl(i,j)];
                        PredResult = PredResult + sim(net_ref, Pred_input');
                    end
                    Landsat_Like_Band2_5_Refl_10m = PredResult/max_time;
                    
                    Landsat_Band10_Temp_slide = Landsat_Band10_Temp_LCmm(l-half_length_2:l+half_length_2, m-half_length_2:m+half_length_2);   % Treatment temperature band
                    output_vector_T = Landsat_Band10_Temp_slide(:);
                    output_vector_T = output_vector_T(~isnan(output_vector_T))';
                    
                    net_temp = configureNetwork(output_size_ref, output_size_temp, trainFcn, hiddenLayerSize);  % Training temperature network
                    PredResult_2 = 0;
                    for kk = 1:max_time
                        net_temp = train(net_temp, output_t, output_vector_T);
                        PredResult_2 = PredResult_2 + sim(net_temp, Landsat_Like_Band2_5_Refl_10m);
                    end
                    
                    Landsat_Like_Temp_10m_trans(i,j,mm) = PredResult_2/max_time.*0.00341802+149;
                    send(progressTracker.q, 1);
                end
            catch ME
                continue
            end 

        end
    end
end

Landsat_Like_Temp_10m_FINAL=sum(Landsat_Like_Temp_10m_trans(i_range, j_range,:),3);
filename_1=['Landsat_Like_Temp_10m_LC' num2str(class_type) '_W' num2str(window_size) '.mat'];
save(filename_1, 'Landsat_Like_Temp_10m_FINAL'); 