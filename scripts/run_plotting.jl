using CLOUD18_AP_Analysis
using Revise
using Dates

# plot -50°C data
# file_name_temp = "C:\\Users\\c7441399\\Documents\\CLOUD18\\AP_run\\-50C\\results\\temp_dew_frost_-50C.csv"
# file_name_o3 = "C:\\Users\\c7441399\\Documents\\CLOUD18\\AP_run\\-50C\\results\\O3_-50C.csv"
# file_name_OH = "C:\\Users\\c7441399\\Documents\\CLOUD18\\AP_run\\HORUS\\HORUS_MPIC_HOxROx_CLOUD18_ALL_SLIM_V2.txt"
# output_file = "output/-50C/O3_temp_OH.png"

# data_temp = load_data(file_name_temp)
# data_o3 = load_data(file_name_o3)
# data_OH = load_data(file_name_OH)

# plot_data([data_temp, data_o3, data_OH],
#     channels=[["TE_Calib_1", "TE_Calib_2", "TE_Calib_3", "TE_Calib_4"], # temperature channels
#               [], # all ozone channels
#               (["OH_ppt"], ["HO2_ppt"])], # OH and HO2 channels
#     ylabels=["Temperature [°C]", "Ozone [ppb]", ("OH [ppt]", "HO₂ [ppt]")],
#     # ylims=[nothing, (-5, 120), ((-0.05, 0.2), nothing)],
#     xlims = ((DateTime(2025,9,22,0,0,0), DateTime(2025,9,27,22,0,0))),
#     savepath=output_file,
#     smoothing=nothing,
#     interactive=false)


##################################################################################################################

# plot -25°C data
# file_name_temp = "C:\\Users\\c7441399\\Documents\\CLOUD18\\AP_run\\-25C\\results\\temp_dew_frost_-25C.csv"
# file_name_o3 = "C:\\Users\\c7441399\\Documents\\CLOUD18\\AP_run\\-25C\\results\\O3_-25C.csv"
# file_name_OH = "C:\\Users\\c7441399\\Documents\\CLOUD18\\AP_run\\HORUS\\HORUS_MPIC_HOxROx_CLOUD18_ALL_SLIM_V2.txt"
# output_file = "output/-25C/O3_temp_OH.png"

# data_temp = load_data(file_name_temp)
# data_o3 = load_data(file_name_o3)
# data_OH = load_data(file_name_OH)

# plot_data([data_temp, data_o3, data_OH],
#     channels=[["TE_Calib_1", "TE_Calib_2", "TE_Calib_3", "TE_Calib_4"], # temperature channels
#               [], # all ozone channels
#               (["OH_ppt"], ["HO2_ppt"])], # OH and HO2 channels
#     ylabels=["Temperature [°C]", "Ozone [ppb]", ("OH [ppt]", "HO₂ [ppt]")],
#     # ylims=[nothing, (-5, 120), ((-0.05, 0.2), nothing)],
#     xlims = ((DateTime(2025,9,28,0,0,0), DateTime(2025,10,2,14,0,0))),
#     savepath=output_file,
#     smoothing=nothing,
#     interactive=false)

##################################################################################################################

# plot -10°C data
# file_name_temp = "C:\\Users\\c7441399\\Documents\\CLOUD18\\AP_run\\-10C\\results\\temp_dew_frost_-10C.csv"
# file_name_o3 = "C:\\Users\\c7441399\\Documents\\CLOUD18\\AP_run\\-10C\\results\\O3_-10C.csv"
# file_name_OH = "C:\\Users\\c7441399\\Documents\\CLOUD18\\AP_run\\HORUS\\HORUS_MPIC_HOxROx_CLOUD18_ALL_SLIM_V2.txt"
# output_file = "output/-10C/O3_temp_OH_avg10min.png"

# data_temp = load_data(file_name_temp)
# data_o3 = load_data(file_name_o3)
# data_OH = load_data(file_name_OH)

# plot_data([data_temp, data_o3, data_OH],
#     channels=[["TE_Calib_1", "TE_Calib_2", "TE_Calib_3", "TE_Calib_4"], # temperature channels
#               [], # all ozone channels
#               (["OH_ppt"], ["HO2_ppt"])], # OH and HO2 channels
#     ylabels=["Temperature [°C]", "Ozone [ppb]", ("OH [ppt]", "HO₂ [ppt]")],
#     # ylims=[nothing, (-5, 120), ((-0.05, 0.2), nothing)],
#     xlims = ((DateTime(2025,10,8,9,0,0), DateTime(2025,10,11,9,30,0))),
#     savepath=output_file,
#     smoothing=Minute(10),
#     interactive=false)

##################################################################################################################

# plot -50C_2 data
file_name_temp = "C:\\Users\\c7441399\\Documents\\CLOUD18\\AP_run\\-50C_2\\results\\temp_dew_frost_-50C_2.csv"
file_name_o3 = "C:\\Users\\c7441399\\Documents\\CLOUD18\\AP_run\\-50C_2\\results\\O3_-50C_2.csv"
file_name_OH = "C:\\Users\\c7441399\\Documents\\CLOUD18\\AP_run\\HORUS\\HORUS_MPIC_HOxROx_CLOUD18_ALL_SLIM_V2.txt"
output_file = "output/-50C_2/O3_temp_OH.png"

data_temp = load_data(file_name_temp)
data_o3 = load_data(file_name_o3)
data_OH = load_data(file_name_OH)

plot_data([data_temp, data_o3, data_OH],
    channels=[["TE_Calib_1", "TE_Calib_2", "TE_Calib_3", "TE_Calib_4"], # temperature channels
              [], # all ozone channels
              (["OH_ppt"], ["HO2_ppt"])], # OH and HO2 channels
    ylabels=["Temperature [°C]", "Ozone [ppb]", ("OH [ppt]", "HO₂ [ppt]")],
    # ylims=[nothing, (-5, 120), ((-0.05, 0.2), nothing)],
    xlims = ((DateTime(2025,10,11,14,30,0), DateTime(2025,10,14,2,30,0))),
    savepath=output_file,
    smoothing=nothing,
    interactive=false)
