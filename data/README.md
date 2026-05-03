# Data Sources

## gtap_output (folder)

Primary author: Fran Moore
Date: May, 2025

The output file `202505_Plants_People_Agriculture.csv` (renamed from `202505_Plants_People_v2` when we removed labor from this file, which is now held in the `_ISO_Revision` and `_Lancet_Revision` files) holds GTAP outputs that serve as inputs to the model to use for the agriculture damage function, as well as a `readme.txt` with metadata and instructions on use.

Primary author: Fran Moore
Date: April, 2026

The output files `202604_Plants_People_ISO_Revision.csv` and `202604_Plants_People_Lancet_Revision` hold GTAP outputs that serve as inputs to the model to use for the labor damage function.

Primary author: Fran Moore
Date: May, 2026

The output files `20260428_Plants_People_results_v4_ISO_Revision.csv` and `20260428_Plants_People_results_v4_Lancet_Revision` hold GTAP outputs that serve as inputs to the model to use for the labor damage function.

## ypc2017 (folder)

Primary author: Lisa Rennels
Date: May, 2025

This folder holds per country GDP CSV files for both the RFF-SPs the individual SSPs, to be used as baselines for calculating agriculture share of GDP in the Agriculture component. To produce the `rffsp_ypc2017.csv` file, we mimic the steps taken for the `rffsp_ypc1990.csv` in the RFF-SPs stored on [Zenodo](https://zenodo.org/records/6016583) and created using scripts from Github [here](https://github.com/rffscghg/rff-socioeconomic-projections).

Note that these are in USD 2011. 

## individual files

- `2025_SectorShare_v2.xlsx` and `202505_SectorShare_v2.csv` hold the information to metadata (former) and directly used (latter) that provides the agricultural share of the economy.
- `dimension_gcm.csv` holds the GCM options used by th emodel
- `region_crosswalk_working.xlsx` and `region_crosswalk.csv` provide crosswalks between GTAP region and MimiGIVE ISO3 country codes (184)
