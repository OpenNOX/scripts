# Scripts

## NodeJS

* **Flatten JSON to CSV -** To be completed at a later time.
* **GSuite API Checker -** To be completed at a later time.

## PowerShell

* **Logic Apps Report Builder -** Loop through a CSV of Logic App details to compile and output a recent activity and status report.
    * **Parameters:**
        * **InputCsvPath -** File path to the input CSV that contains Logic App details to loop over and build a report from.
            * **CSV Schema -** `SubscriptionId,ResourceGroupName,LogicAppName,CustomerName,Direction`
            * **Default Value -** Current working directory's `inputs` directory named `Logic Apps List.csv`.
            * **Notes:**
                * Records that have a `SubscriptionId` that begins with a hash (`#`) will not be included in the report. This is most likely only used for development purposes.
        * **OutputDir -** Path to the directory of where to output the generated CSV files.
            * **Default Value -** Current working directory's `outputs` directory.
        * **ThresholdOffset -** Number of days to offset the Logic App run history filter by.
            * **Default Value -** 0
        * **SkipAzAuth -** Skip Azure authentication?
            * **Notes:**
                * This option is only useful when your terminal is already authenticated and connected to Azure.
        * **SkipAzData -** Skip retrieving Logic App run history details from Azure?
            * **Notes:**
                * This option is only useful when you would like to rebuild the report from existing data in the `OutputDir`.
    * **Outputs:**
        * **Logic Apps Run History (Raw).csv -** Logic App run history for each of the Logic Apps listed in the `InputCsvPath`.
        * **Logic Apps Run History (Report).csv -** Formatted report of the raw Logic App run history details.
