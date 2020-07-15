# Scripts

## NodeJS

* **Flatten JSON to CSV -** To be completed at a later time.
* **GSuite API Checker -** To be completed at a later time.

## PowerShell

* **Logic Apps Report Builder -** Loops through a CSV of Logic Apps to compile and output a recent activity and status report. The report will show the number of executions and their status.
    * **Parameters:**
        * **InputCsv -** File path to the input CSV that contains Logic App details to loop over and build a report from.
            * **CSV Schema -** `SubscriptionId,ResourceGroupName,LogicAppName,CustomerName,Direction`
            * **Default Value -** Current working directory's `inputs` directory named `Logic Apps List.csv`.
            * **Notes:**
                * Records that have a `SubscriptionId` that begins with a hash (`#`) will not be included in the report. This is most likely only used for development purposes.
        * **OutputDir -** File path to the directory of where to output the generated CSV files.
            * **Default Value -** Current user's `Desktop` directory.
        * **SkipAzAuth -** Skip Azure authentication?
            * **Default Value -** False
            * **Notes:**
                * This option is only useful when your terminal is already authenticated and connected to Azure.
    * **Outputs:**
        * **Logic Apps Run History (Raw).csv -** Contains all Logic App execution history for each of the Logic Apps listed in the `InputCsv`.
        * **Logic Apps Run History (Report).csv -** Contains a more human-readable report of the Logic App execution history for each of the Logic Apps listed in the `InputCsv`.
    * **To Dos:**
        * Further refactor the script to not store all Logic App Run History in memory, but instead have it write to the respective generated output files. This will ensure that if the Logic App List CSV grows that the machine that is running it will not run out of memory.
