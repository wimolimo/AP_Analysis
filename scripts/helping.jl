using CLOUD18_AP_Analysis
using Revise
using Dates

# checking if the stages.txt file is created correctly
folder = "C:\\Users\\c7441399\\Documents\\CLOUD18\\AP_run\\CLOUD_log_stages"
files = sort(filter(f -> endswith(f, ".txt"), readdir(folder, join=true)))
println("Found $(length(files)) files:")
println.(files)
merge_log_files(files, "stages.txt")

output_path = joinpath(folder, "stages.txt")

open(output_path, "w") do out
    for f in files
        write(out, read(f, String))
        write(out, "\n")
    end
end

load_stages!(output_path)