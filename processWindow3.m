function [input_x, output_t] = processWindow3(sentinel_upscale_bands, landsat_ref_bands, l, m, half_length_2)

    row_range = (l-half_length_2):(l+half_length_2);
    col_range = (m-half_length_2):(m+half_length_2);
    

    sentinel_window = sentinel_upscale_bands(row_range, col_range, :);
    landsat_window = landsat_ref_bands(row_range, col_range, :);
    

    [rows, cols, num_bands] = size(sentinel_window);
    num_pixels = rows * cols;
    

    sentinel_reshaped = reshape(sentinel_window, num_pixels, num_bands);
    landsat_reshaped = reshape(landsat_window, num_pixels, num_bands);
    

    valid_pixels = all(~isnan(sentinel_reshaped), 2) & all(~isnan(landsat_reshaped), 2);
    

    input_x = sentinel_reshaped(valid_pixels, :)';
    output_t = landsat_reshaped(valid_pixels, :)';
end