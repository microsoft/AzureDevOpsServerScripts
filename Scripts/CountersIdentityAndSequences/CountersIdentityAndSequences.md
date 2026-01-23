# Azure DevOps Server Advisory: Check Identity/Sequence Headroom to Prevent ID Exhaustion

As Azure DevOps Server (formerly Team Foundation Server) approaches two decades in the field, many on-premises deployments have grown well beyond their original scale. In very large environments, some busy integer-based IDs (for example, FileId) can approach the upper bound of the `INT` data type (2,147,483,647). Azure DevOps cloud service continuously monitors these counters and proactively mitigates risk; we don’t have that visibility into customer-hosted on-premises environments.

This post is a proactive health check for customers operating at significant scale. A small number of very large on-premises customers have recently encountered outages after file identifiers (FileId) reached its maximum value allowed by the INT data type. We want to help you avoid that.

Our goal is to help you stay ahead of scale limits and keep your Azure DevOps Server running healthy. If you need assistance running the queries or interpreting results, reach out to Microsoft Customer Support Services (CSS), and they can help get you started.

Azure DevOps Team

## Who should act

*   Large, long-running Azure DevOps Server installations
*   Environments with very high activity (e.g., millions of file versions, artifacts, or work items)

## What to do now (safe, read-only checks)

Run the following T-SQL in each of your project collection databases. These queries **do not modify data**; they report current utilization for `INT` identity columns and sequences.

See the SQL script: [Check-CountersIdentityAndSequences.sql](Check-CountersIdentityAndSequences.sql)

## How to interpret the results
We have mitigations, and/or are working on permanent solutions for the small set of values we see exceeding the max Int values.  

Generally speaking, if anything shows up as >80% please do create a CSS ticket so we have awareness of your company's usage pattern.  

*   **≥ 90%**: Critical—engage Microsoft Customer Support Services (CSS) immediately with your findings.
*   **80–89%**: Warning—open a case with Customer Support Services (CSS) to review mitigations before growth pushes you into the critical range.
*   **< 80%**: Monitor periodically (e.g., quarterly or after major ingest/migration events).

More specifically we are aware of a few common high usage values.  We'll list them here along with potential mitigations.

Azure DevOps uses a combination of Identity Columns, Sequences and a table called tbl_Counter to get monotonously increasing values.

### **tbl_Counter Objects**

tbl_Counter is a table used to provide Identity column like functionality without actually having an Identity column.  In addition to being used to get the next value, it can also be used to get a range of next values.  

Sample Query Results (from an actual database in ADO Hosted)
| ObjectType | PartitionId | DataspaceId | ObjectName | ObjectDataType | IncrementValue | MinimumValue   | MaximumValue   | CurrentValue  | PercentageUsed |
|----------------|-------------|-------------|------------------------------|----------------|----------------|----------------|----------------|---------------|----------------|
| tbl_Counter    | 1           | 5           | OrchestrationInstanceId      | int            | 1              | 1              | 2147483647     | 1958203183    | 91             |
| tbl_Counter    | 1           | 5           | OrchestrationSessionId       | int            | 1              | 1              | 2147483647     | 1965151061    | 91             |

The ObjectName is the name of the Column associated with this counter.

The ObjectDataType is actually misleading.  On the tbl_Counter itself the CounterValue column is actually a BigInt.  There is no way to tell from the tbl_Counter itself if the rest of the application code is Int or BigInt.  For that reason, we've marked it as Int in the query to highlight high usage.

#### OrchestrationInstanceId OrchestrationSessionId 
There are only 2 Objects on tbl_Counter that we've seen approaching the MAX INT boundary in Hosted ADO:  OrchestrationInstanceId  OrchestrationSessionId 

As of January 2026, we are in process making changes to the code to allow these to scale to BigInt in the Hosted environment.  We expect these changes will changes for Azure DevOps Server 2025 by June 2026.  We will update this document when we know the exact build that will include the changes.

### **Identity Columns**

| ObjectType | PartitionId | DataspaceId | ObjectName | ObjectDataType | IncrementValue | MinimumValue   | MaximumValue   | CurrentValue  | PercentageUsed |
|----------------|-------------|-------------|------------------------------|----------------|----------------|----------------|----------------|---------------|----------------|
| Identity Column | 1           | NULL           | dbo.tbl_Command.CommandId | int            | -1             | -2147483648    | 2147483647     | 1758290897	   | 81             |


#### tbl_Command
tbl_Command is known to roll over in On Premises.  On ADO Server the Insert stored proc prc_LogActivity will Catch an overflow error 8115 and will Truncate tbl_Command and tbl_Parameter.  This solution has been in place for a very long time On Premises and works well.  Additionally, there is a cleanup job that removes stale data, keeping the table from overgrowing.


### **SQL Sequences sys.sequences** (from an actual database in ADO Hosted)

| ObjectType | PartitionId | DataspaceId | ObjectName | ObjectDataType | IncrementValue | MinimumValue   | MaximumValue   | CurrentValue  | PercentageUsed |
|----------------|-------------|-------------|------------------------------|----------------|----------------|----------------|----------------|---------------|----------------|
| sys.sequences  | 0           | 0           | Sequence_FileId_1_2          | int            | -1             | -2147483648    | 2147483647     | -1945728066   | 90             |
| sys.sequences  | 0           | 0           | Sequence_FileId_1            | int            | 1              | -2147483648    | 2147483647     | 1400058833    | 65             |

#### FileId
We have had outages both in Hosted and On Premises related to the FileId sequences.  The FileId sequence is shared across many features within ADO, and by default limited to the positive integer range.  There is a FileId sequence per PartitionId.  In On Premises the only PartitionId used is 1.  In Hosted each host has a unique PartitionId.  This allows us to host multiple customers in a single database.  

In 2020 we first experienced the issue of running out of available positive integers in some of our busiest Hosted databases.  To mitigate this a change was added to allow the use of the negative Integer range.  This also eventually ran out, and code was added to allow the reuse of negative FileIds.  The reuse of the negative FileIds worked, however not all consumers of FileIds can use them.  In 2024 the first customer hit the limit of available positive Integers forcing us to add code to reuse positive Integers.

We can help enable these Integer based mitigations for On Premises customers if needed.

The long-term solution is to move to the BigInt data type.  At the beginning of 2025, we began the very long, slow process of converting most FileIds to BigInt.  We have been slowly staging the changes in hosted and rolling through the codebase.  These changes have been flowing into the On Premises release.  We expect that On Premises will get all of the changes by the middle of 2026.  We will update this document when we know the exact build that will include the changes. 

Follow Up Queries For FileId Related sequences

See the SQL script: [FollowUp-FileId-Queries.sql](FollowUp-FileId-Queries.sql)