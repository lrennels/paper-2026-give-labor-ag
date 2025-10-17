# Data Sources

## gtap_output (folder)

Primary author: Fran Moore
Date: May, 2025

The output file `202505_Plants_People_v2.csv` holds GTAP outputs that serve as inputs to the model, as well as a `readme.txt` with metadata and instructions on use. The `04_process_gtap_output.R` file also provides a short script for diagnostic plots.

## ypc2017 (folder)

Primary author: Lisa Rennels
Date: May, 2025

This folder holds per country GDP CSV files for both the RFF-SPs the individual SSPs, to be used as baselines for calculating agriculture share of GDP in the Agriculture component. To produce the `rffsp_ypc2017.csv` file, we mimic the steps taken for the `rffsp_ypc1990.csv` in the RFF-SPs stored on [Zenodo](https://zenodo.org/records/6016583) and created using scripts from Github [here](https://github.com/rffscghg/rff-socioeconomic-projections).

Note that these are in USD 2011. 

## individual files

- `2025_SectorShare_v2.xlsx` and `202505_SectorShare_v2.csv` hold the information to metadata (former) and directly used (latter) that provides the agricultural share of the economy by (1) select crops (2) all crops.
- `dimension_gcm.csv` holds the GCM options used by th emodel
- `region_crosswalk_working.xlsx` and `region_crosswalk.csv` provide crosswalks between GTAP region and MimiGIVE ISO3 country codes (184)
