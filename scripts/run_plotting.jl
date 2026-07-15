using CLOUD18_AP_Analysis
using Revise
using Dates

file_name_temp = "C:\\Users\\c7441399\\Documents\\CLOUD18\\AP_run\\-50C\\results\\temp_dew_frost_-50C.csv"
file_name_o3 = "C:\\Users\\c7441399\\Documents\\CLOUD18\\AP_run\\-50C\\results\\O3_-50C.csv"
file_name_OH = "C:\\Users\\c7441399\\Documents\\CLOUD18\\AP_run\\HORUS\\HORUS_MPIC_HOxROx_CLOUD18_ALL_SLIM_V2.txt"
output_file = "output/-50C/O3_temp.png"

data_temp = load_data(file_name_temp)
data_o3 = load_data(file_name_o3)
data_OH = load_data(file_name_OH)

#example of plotting multiple datasets with different channels and ylims, on the same x-axis
plot_data([data_temp, data_o3, data_OH],
    channels=[["TE_Calib_1", "TE_Calib_2", "TE_Calib_3", "TE_Calib_4"], [], (["OH_ppt"], ["HO2_ppt"])], 
    ylims=[nothing, (-5, 120), ((-0.1, 0.2), (-0.5, 2.2))],
    xlims=(Dates.unix2datetime(1758550000-3600), Dates.unix2datetime(1759010000+3600)),
    savepath=output_file)

