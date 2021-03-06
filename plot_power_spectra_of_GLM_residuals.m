function plot_power_spectra_of_GLM_residuals(path_to_results, TR, cutoff_freq, assumed_exper_freq, true_exper_freq)

   %-By Wiktor Olszowy, University of Cambridge, olszowyw@gmail.com
   %-Written following study 'Accurate autocorrelation modeling substantially improves fMRI reliability'
   %-https://www.nature.com/articles/s41467-019-09230-w.pdf
   %-May 2018
   %-Given fMRI task results in AFNI, FSL or SPM, this script plots power spectra of GLM residuals.
   %-If there is strong structure visible in the GLM residuals (the power spectra are not flat), the first level results are likely confounded.

   %-tested on Linux
   %-you need on your path >= MATLAB 2017b, AFNI and FSL


   %-specify the default values for the cutoff frequency used by the high-pass filter,
   %-for the assumed experimental design frequency and for the true experimental design frequency;
   %-10 chosen, as it is beyond the plotted frequencies
   if ~exist('cutoff_freq',        'var'), cutoff_freq         = 10; end
   if ~exist('assumed_exper_freq', 'var'), assumed_exper_freq  = 10; end
   if ~exist('true_exper_freq',    'var'), true_exper_freq     = 10; end

   %-Fast Fourier Transform (FFT) will pad the voxel-wise time series to that length with trailing zeros (if no. of time points lower) or truncate to that length (if no. of time points higher)
   fft_n = 512;

   initial_path = pwd;
   cd(path_to_results)
   
   %-read GLM residuals

   %-for AFNI
   AFNI_res4d_name     = dir('whitened_errts.*.BRIK');
   if length(AFNI_res4d_name) > 0
      AFNI_res4d_name  = AFNI_res4d_name.name;
      system(['3dcalc -a ' AFNI_res4d_name ' -expr "a" -prefix res4d.nii']);
      res4d            = niftiread('res4d.nii');

   %-for FSL
   elseif exist('stats/res4d.nii.gz', 'file') == 2
      res4d            = niftiread('stats/res4d.nii.gz');
   elseif exist('stats/res4d.nii', 'file') == 2
      res4d            = niftiread('stats/res4d.nii');

   %-for SPM
   elseif exist('Res_0001.nii',       'file') == 2
      SPM_res4d_name   = dir('Res_*.nii');
      SPM_res4d_all    = '';
      for i            = 1:length(SPM_res4d_name)
         SPM_res4d_all = [SPM_res4d_all ' ' SPM_res4d_name(i).name];
      end
      system(['fslmerge -t res4d ' SPM_res4d_all]);
      res4d            = niftiread('res4d.nii.gz');
   else

      disp('No GLM residuals found! If you run SPM, remember to put command VRes = spm_write_residuals(SPM, NaN) at the end of the SPM script. Otherwise, SPM by default deletes the GLM residuals.');
      return

   end

   %-calculate the power spectra

   dims                           = size(res4d);
   power_spectra_of_GLM_residuals = zeros(fft_n, 1);
   no_of_brain_voxels             = 0;
   
   for i1       = 1:dims(1)
      
      for i2    = 1:dims(2)
         
         for i3 = 1:dims(3)

            ts  = squeeze(res4d(i1, i2, i3, :));
            
            if sum(isnan(ts)) == 0

               if (std(ts)    ~= 0)

                  %-make signal variance equal to 1
                  ts                             = ts/(std(ts) + eps);

                  %-compute the discrete Fourier transform (DFT)
                  DFT                            = fft(ts, fft_n);

                  power_spectra_of_GLM_residuals = power_spectra_of_GLM_residuals + ((abs(DFT)).^2)/min(dims(4), fft_n);

                  no_of_brain_voxels             = no_of_brain_voxels + 1;

               end

            end

         end

      end

   end

   %-average power spectra over all brain voxels
   power_spectra_of_GLM_residuals = power_spectra_of_GLM_residuals / no_of_brain_voxels;

   %-save the power spectra
   save('power_spectra_of_GLM_residuals');

   %-make the plot
   figure('rend', 'painters', 'pos', [0 0 400 200], 'Visible', 'off');

      f      = linspace(0, 0.5/TR, 257);
      max_y  = max(power_spectra_of_GLM_residuals);
      h1     = plot(f, power_spectra_of_GLM_residuals(1:257), 'r'); hold on;
      h4     = plot(cutoff_freq,        0,     'k*');  hold on;
      h5     = plot(cutoff_freq,        max_y, 'k*');  hold on;
      h6     = plot(assumed_exper_freq, 0,     'c*');  hold on;
      h7     = plot(assumed_exper_freq, max_y, 'c*');  hold on;
      h8     = plot(true_exper_freq,    0,     'm*');  hold on;
      h9     = plot(true_exper_freq,    max_y, 'm*');  hold on;
      h10    = plot([0 0.5/TR], [1 1],         'k--'); hold on;
      hx     = xlabel({' ', 'Frequency [Hz]', ' '});
      htitle = title('Power spectra of GLM residuals', 'interpreter', 'none');

      xlim([0 0.5/TR]);
      ylim([0 max_y]);

      set([h1 h10],    'LineWidth', 1.25);
      set([hx htitle], 'FontSize',  7);
      set(gca, 'XTick',      linspace(0, 0.5/TR, 6));
      set(gca, 'XTickLabel', round(linspace(0, 0.5/TR, 6), 2));
      set(gca, 'FontSize', 7);

      if (power_spectra_of_GLM_residuals(257) < 0) || (max_y > 2)
         legend([h10 h4 h6 h8], {'Ideal power spectra', 'High pass filter frequency cutoff', 'Assumed design frequency', 'True design frequency'}, 'box', 'off', 'FontSize', 7, 'Location', 'northeast');
      else
         legend([h10 h4 h6 h8], {'Ideal power spectra', 'High pass filter frequency cutoff', 'Assumed design frequency', 'True design frequency'}, 'box', 'off', 'FontSize', 7, 'Location', 'southeast');
      end

   figname = 'power_spectra_of_GLM_residuals';
   print (figname, '-dpng');

   cd(initial_path);

end
