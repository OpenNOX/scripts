-- Variables:
--   WorkflowId_RunId - Table to Group
--   EMPLOYEEID       - Grouping Column

SELECT *
FROM
(
  SELECT   EMPLOYEEID AS GROUP_ID, COUNT(*) AS GROUP_COUNT
  FROM     [WorkflowId_RunId]
  GROUP BY EMPLOYEEID
) AS GROUPED
JOIN   [WorkflowId_RunId] AS UNGROUPED
       ON GROUPED.GROUP_ID = UNGROUPED.EMPLOYEEID
