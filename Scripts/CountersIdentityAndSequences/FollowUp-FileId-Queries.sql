-- Follow-up checks for FileId related sequences and registry entries

-- Collection DB Registry
SELECT * FROM tbl_RegistryItems where PartitionId = 1 AND ParentPath like '#\FeatureAvailability\Entries\VisualStudio.FrameworkService.FileService.FileIdSecondaryRange%'

SELECT * FROM tbl_RegistryItems where PartitionId = 1 AND ParentPath like '#\FeatureAvailability\Entries\VisualStudio.FrameworkService.FileService.ReuseSecondaryRangeFileId%'

-- AzureDevOps_Configuration DB Registry, will not exist in Collection DB
SELECT * FROM tbl_RegistryItems where PartitionId = 1 AND ParentPath like '#\Service\FileService%' AND ChildItem = 'OwnerIdsUsingSecondaryRange\'
