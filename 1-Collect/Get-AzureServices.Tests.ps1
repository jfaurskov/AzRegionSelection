BeforeAll {
    # Use Join-Path for cross-platform compatibility
    $scriptPath = Join-Path $PSScriptRoot 'Get-AzureServices.ps1'
    $modulesPath = Join-Path $PSScriptRoot 'modules'
    
    # Extract function definitions from the script for testing
    # The functions use Set-Variable with -Scope Script, which means we need to
    # dot-source them into the current scope rather than using a module
    $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
    $functionDefinitions = $scriptAst.FindAll({ param($ast) $ast -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    
    # Define each function in the current scope using scriptblocks
    # This is safer than Invoke-Expression as it creates typed scriptblock objects
    foreach ($funcDef in $functionDefinitions) {
        $funcBlock = [scriptblock]::Create($funcDef.Extent.Text)
        . $funcBlock
    }
}

Describe "Get-AzureServices.ps1 Tests" {
    Context "Parameter Validation" {
        It "Should accept valid scopeType values" {
            $validScopes = @('singleSubscription', 'resourceGroup', 'multiSubscription')
            
            # Parse the script to check parameter validation
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'ValidateSet.*singleSubscription.*resourceGroup.*multiSubscription'
        }

        It "Should have all expected script parameters defined" {
            $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
            $paramBlock = $scriptAst.ParamBlock
            $params = $paramBlock.Parameters
            
            $paramNames = $params | ForEach-Object { $_.Name.VariablePath.UserPath }
            $paramNames | Should -Contain 'scopeType'
            $paramNames | Should -Contain 'subscriptionId'
            $paramNames | Should -Contain 'resourceGroupName'
            $paramNames | Should -Contain 'workloadFile'
            $paramNames | Should -Contain 'fullOutputFile'
            $paramNames | Should -Contain 'summaryOutputFile'
            $paramNames | Should -Contain 'includeCost'
        }

        It "Should have correct number of script parameters" {
            $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
            $paramBlock = $scriptAst.ParamBlock
            $params = $paramBlock.Parameters
            
            $params.Count | Should -Be 7
        }

        It "Should have default values for output files" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'fullOutputFile.*=.*"resources.json"'
            $scriptContent | Should -Match 'summaryOutputFile.*=.*"summary.json"'
        }

        It "Should default includeCost to false" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'includeCost.*=.*\$false'
        }

        It "Should default scopeType to singleSubscription" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match "scopeType.*=.*'singleSubscription'"
        }
    }

    Context "Function Definitions" {
        It "Should define Get-Property function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Function Get-Property'
        }

        It "Should define Get-SingleData function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Function Get-SingleData'
        }

        It "Should define Get-Method function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Function Get-Method'
        }

        It "Should define Get-rType function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'function Get-rType'
        }

        It "Should define Invoke-CmdLine function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Function Invoke-CmdLine'
        }

        It "Should define Get-MultiLoop function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Function Get-MultiLoop'
        }

        It "Should define Invoke-CostReportSchedule function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Function Invoke-CostReportSchedule'
        }

        It "Should define Get-CostReport function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Function Get-CostReport'
        }

        It "Should define Get-MeterId function" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Function Get-MeterId'
        }
    }

    Context "Get-Property Function" {
        AfterEach {
            # Clean up script-scoped test variable to prevent test pollution
            Remove-Variable -Name 'testResult' -Scope Script -ErrorAction SilentlyContinue
        }

        It "Should extract simple property from object" {
            $testObject = [PSCustomObject]@{
                name = "TestResource"
                type = "microsoft.test/resource"
            }
            
            Get-Property -object $testObject -property "name" -outputVarName "testResult"
            $script:testResult | Should -Be "TestResource"
        }

        It "Should extract nested property from object" {
            $testObject = [PSCustomObject]@{
                properties = [PSCustomObject]@{
                    sku = [PSCustomObject]@{
                        name = "Standard"
                    }
                }
            }
            
            Get-Property -object $testObject -property "properties.sku.name" -outputVarName "testResult"
            $script:testResult | Should -Be "Standard"
        }

        It "Should handle property with multiple levels of nesting" {
            $testObject = [PSCustomObject]@{
                level1 = [PSCustomObject]@{
                    level2 = [PSCustomObject]@{
                        level3 = "DeepValue"
                    }
                }
            }
            
            Get-Property -object $testObject -property "level1.level2.level3" -outputVarName "testResult"
            $script:testResult | Should -Be "DeepValue"
        }

        It "Should return null for non-existent property" {
            $testObject = [PSCustomObject]@{
                name = "TestResource"
            }
            
            Get-Property -object $testObject -property "nonexistent" -outputVarName "testResult"
            $script:testResult | Should -BeNullOrEmpty
        }
    }

    Context "Invoke-CmdLine Function" {
        AfterEach {
            # Clean up script-scoped test variable to prevent test pollution
            Remove-Variable -Name 'cmdResult' -Scope Script -ErrorAction SilentlyContinue
        }

        It "Should execute simple command and store result" {
            Invoke-CmdLine -cmdLine '1 + 1' -outputVarName "cmdResult"
            $script:cmdResult | Should -Be "2.00"
        }

        It "Should execute string command and store result" {
            Invoke-CmdLine -cmdLine '"Hello" + " World"' -outputVarName "cmdResult"
            $script:cmdResult | Should -Be "Hello World"
        }

        It "Should format numeric results to 2 decimal places" {
            Invoke-CmdLine -cmdLine '10 / 3' -outputVarName "cmdResult"
            $script:cmdResult | Should -Be "3.33"
        }
    }

    Context "Get-MeterId Function" {
        AfterEach {
            # Clean up script-scoped test variable to prevent test pollution
            Remove-Variable -Name 'meterIds' -Scope Script -ErrorAction SilentlyContinue
        }

        It "Should extract unique meter IDs for a resource" {
            $mockCsv = @(
                [PSCustomObject]@{ resourceId = "/subscriptions/123/resources/test"; meterId = "meter-1" }
                [PSCustomObject]@{ resourceId = "/subscriptions/123/resources/test"; meterId = "meter-2" }
                [PSCustomObject]@{ resourceId = "/subscriptions/123/resources/other"; meterId = "meter-3" }
            )
            
            Get-MeterId -ResourceId "/subscriptions/123/resources/test" -csvObject $mockCsv
            $script:meterIds | Should -Contain "meter-1"
            $script:meterIds | Should -Contain "meter-2"
            $script:meterIds | Should -Not -Contain "meter-3"
        }

        It "Should return empty array for non-existent resource" {
            $mockCsv = @(
                [PSCustomObject]@{ resourceId = "/subscriptions/123/resources/test"; meterId = "meter-1" }
            )
            
            Get-MeterId -ResourceId "/subscriptions/123/resources/nonexistent" -csvObject $mockCsv
            $script:meterIds | Should -BeNullOrEmpty
        }

        It "Should handle duplicate meter IDs" {
            $mockCsv = @(
                [PSCustomObject]@{ resourceId = "/subscriptions/123/resources/test"; meterId = "meter-1" }
                [PSCustomObject]@{ resourceId = "/subscriptions/123/resources/test"; meterId = "meter-1" }
            )
            
            Get-MeterId -ResourceId "/subscriptions/123/resources/test" -csvObject $mockCsv
            $script:meterIds.Count | Should -Be 1
        }
    }

    Context "Module JSON Files" {
        It "Should have valid sku.json module file" {
            $skuPath = Join-Path $modulesPath 'sku.json'
            Test-Path $skuPath | Should -Be $true
            
            $json = Get-Content $skuPath -Raw | ConvertFrom-Json
            $json | Should -Not -BeNullOrEmpty
            # JSON should be an array of resource type definitions
            @($json).Count | Should -BeGreaterThan 0
        }

        It "Should have valid dataSize.json module file" {
            $dataSizePath = Join-Path $modulesPath 'dataSize.json'
            Test-Path $dataSizePath | Should -Be $true
            
            $json = Get-Content $dataSizePath -Raw | ConvertFrom-Json
            $json | Should -Not -BeNullOrEmpty
        }

        It "Should have valid ipConfig.json module file" {
            $ipConfigPath = Join-Path $modulesPath 'ipConfig.json'
            Test-Path $ipConfigPath | Should -Be $true
            
            $json = Get-Content $ipConfigPath -Raw | ConvertFrom-Json
            $json | Should -Not -BeNullOrEmpty
        }

        It "Should have valid resiliencyProperties.json module file" {
            $resiliencyPath = Join-Path $modulesPath 'resiliencyProperties.json'
            Test-Path $resiliencyPath | Should -Be $true
            
            $json = Get-Content $resiliencyPath -Raw | ConvertFrom-Json
            $json | Should -Not -BeNullOrEmpty
        }

        It "Should have resourceType property in each module entry" {
            $moduleFiles = @('sku.json', 'dataSize.json', 'ipConfig.json', 'resiliencyProperties.json')
            
            foreach ($file in $moduleFiles) {
                $filePath = Join-Path $modulesPath $file
                $json = Get-Content $filePath -Raw | ConvertFrom-Json
                
                foreach ($entry in $json) {
                    $entry.resourceType | Should -Not -BeNullOrEmpty -Because "Each entry in $file should have a resourceType"
                }
            }
        }
    }

    Context "Get-Method Function" {
        BeforeAll {
            # Save current location and change to the script directory for relative path resolution
            $originalLocation = Get-Location
            Set-Location $PSScriptRoot
        }

        AfterAll {
            # Restore original location
            Set-Location $originalLocation
        }

        AfterEach {
            # Clean up script-scoped variables to prevent test pollution
            Remove-Variable -Name 'resiliencyProperties' -Scope Script -ErrorAction SilentlyContinue
            Remove-Variable -Name 'dataSize' -Scope Script -ErrorAction SilentlyContinue
            Remove-Variable -Name 'ipAddress' -Scope Script -ErrorAction SilentlyContinue
            Remove-Variable -Name 'sku' -Scope Script -ErrorAction SilentlyContinue
        }

        It "Should handle resiliencyProperties flag type" {
            $testObject = [PSCustomObject]@{
                type = "microsoft.storage/storageaccounts"
                sku = [PSCustomObject]@{ name = "Standard_GRS" }
            }
            
            Get-Method -resourceType "microsoft.storage/storageaccounts" -flagType "resiliencyProperties" -object $testObject
            $script:resiliencyProperties | Should -Not -BeNullOrEmpty
        }

        It "Should handle dataSize flag type" {
            $testObject = [PSCustomObject]@{
                type = "microsoft.Compute/disks"
                properties = [PSCustomObject]@{ diskSizeGB = 128 }
            }
            
            Get-Method -resourceType "microsoft.Compute/disks" -flagType "dataSize" -object $testObject
            $script:dataSize | Should -Be 128
        }

        It "Should handle ipConfig flag type" {
            $testObject = [PSCustomObject]@{
                type = "microsoft.Network/publicipaddresses"
                properties = [PSCustomObject]@{ ipAddress = "10.0.0.1" }
            }
            
            Get-Method -resourceType "microsoft.Network/publicipaddresses" -flagType "ipConfig" -object $testObject
            $script:ipAddress | Should -Be "10.0.0.1"
        }

        It "Should handle Sku flag type" {
            $testObject = [PSCustomObject]@{
                type = "microsoft.Compute/disks"
                properties = [PSCustomObject]@{ tier = "Premium" }
            }
            
            Get-Method -resourceType "microsoft.Compute/disks" -flagType "Sku" -object $testObject
            $script:sku | Should -Be "Premium"
        }

        It "Should return N/A for unsupported resource type" {
            $testObject = [PSCustomObject]@{
                type = "microsoft.unsupported/resource"
            }
            
            Get-Method -resourceType "microsoft.unsupported/resource" -flagType "dataSize" -object $testObject
            $script:dataSize | Should -Be "N/A"
        }
    }

    Context "Get-rType Function" {
        BeforeAll {
            $originalLocation = Get-Location
            Set-Location $PSScriptRoot
        }

        AfterAll {
            Set-Location $originalLocation
        }

        AfterEach {
            # Clean up script-scoped variables to prevent test pollution
            Remove-Variable -Name 'testDataSize' -Scope Script -ErrorAction SilentlyContinue
            Remove-Variable -Name 'testResiliency' -Scope Script -ErrorAction SilentlyContinue
        }

        It "Should extract property when isContainedInOriginalGraphOutput is true" {
            $testObject = [PSCustomObject]@{
                properties = [PSCustomObject]@{ diskSizeGB = 256 }
            }
            
            $filePath = Join-Path $modulesPath 'dataSize.json'
            Get-rType -filePath $filePath -object $testObject -outputVarName "testDataSize" -resourceType "microsoft.Compute/disks"
            $script:testDataSize | Should -Be 256
        }

        It "Should return N/A when resource type is not in the module file" {
            $testObject = [PSCustomObject]@{
                name = "test"
            }
            
            $filePath = Join-Path $modulesPath 'dataSize.json'
            Get-rType -filePath $filePath -object $testObject -outputVarName "testDataSize" -resourceType "microsoft.nonexistent/resource"
            $script:testDataSize | Should -Be "N/A"
        }

        It "Should handle array properties correctly" {
            $testObject = [PSCustomObject]@{
                sku = [PSCustomObject]@{ name = "Standard_LRS" }
            }
            
            $filePath = Join-Path $modulesPath 'resiliencyProperties.json'
            Get-rType -filePath $filePath -object $testObject -outputVarName "testResiliency" -resourceType "microsoft.storage/storageaccounts"
            $script:testResiliency | Should -Not -BeNullOrEmpty
        }
    }

    Context "Script Logic" {
        It "Should suppress Azure breaking change warnings" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'SuppressAzurePowerShellBreakingChangeWarnings'
        }

        It "Should handle all three scope types" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match "'singleSubscription'"
            $scriptContent | Should -Match "'resourceGroup'"
            $scriptContent | Should -Match "'multiSubscription'"
        }

        It "Should export results to JSON file" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'ConvertTo-Json.*Out-File.*fullOutputFile'
        }

        It "Should generate summary with grouped resources" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'Group-Object -Property ResourceType'
        }

        It "Should include resource metadata in output" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'ResourceType'
            $scriptContent | Should -Match 'ResourceName'
            $scriptContent | Should -Match 'ResourceLocation'
            $scriptContent | Should -Match 'ResourceSubscriptionId'
            $scriptContent | Should -Match 'ResourceID'
            $scriptContent | Should -Match 'ResourceSku'
            $scriptContent | Should -Match 'ResourceZones'
        }
    }

    Context "Cost Report Integration" {
        It "Should use correct API version for cost management" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'api-version=2025-03-01'
        }

        It "Should use AmortizedCost metric" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match '"AmortizedCost"'
        }

        It "Should handle cost report polling" {
            $scriptContent = Get-Content $scriptPath -Raw
            $scriptContent | Should -Match 'while.*StatusCode.*202'
        }
    }
}
