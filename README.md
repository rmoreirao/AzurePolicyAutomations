# AzurePolicyAutomations

Extracts data from Azure Resource Graph, stores it into CSV format, and perform some Transformations / Data Analysis using Jupyter Notebook 

# How to execute it

- Login to Azure Powershell
- Execute script "ExportResourceGraphQueries.ps1" to export all the Resource Graph Data
- Manually download "Entra ID Users" and store it into folder /output - on this example name of the file is "exportUsers_2025-1-23.csv"
- Execute the "analysis/AnalysisCompliancy.ipynb" jupyter notebook 

# References
- https://github.com/ptsouk/Policy-as-Code/blob/68b2f675b8f9e4475cc7c04d2899cc6ad495e43f/README.md
