# Dependency Check Reference

## MCP Tools

### get_dependency_vulnerabilities

Retrieves all dependency vulnerabilities for a repository branch from the latest Qualimetry analysis.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `repositoryName` | string | Yes | The repository name, e.g. `owner/repo-name`. Case-insensitive; the server normalises the value. |
| `branchName` | string | Yes | Current branch (from `git branch --show-current`) |
| `analysisName` | string | No | The analysis project name for mono-repo disambiguation. Case-insensitive. Leave empty for single-project repositories. |

**Returns:** JSON object with `Total` count and `Dependencies` array.

### get_dependency_upgrade_advice

Performs a live lookup for a single dependency to find the next safe version and latest available version.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `ecosystem` | string | Yes | Package ecosystem: `npm`, `maven`, `nuget`, `pypi`, `cargo`, `go`, `rubygems` |
| `packageName` | string | Yes | Package name as used by the registry (e.g., `lodash`, `org.apache.logging.log4j/log4j-core`, `Newtonsoft.Json`) |
| `currentVersion` | string | Yes | Current vulnerable version (e.g., `4.17.10`) |

**Returns:** JSON `DependencyUpgradeAdvice` object.

---

## Response Schema: DependencyVulnerabilitiesResult

```json
{
  "Total": 5,
  "Dependencies": [
    {
      "DependencyName": "lodash-4.17.10.tgz",
      "Ecosystem": "Npm",
      "PackageName": "lodash",
      "Version": "4.17.10",
      "PackageUrl": "pkg:npm/lodash@4.17.10",
      "VulnerabilityCount": 3,
      "RiskScore": 7.5,
      "Vulnerabilities": [
        {
          "Name": "CVE-2020-28500",
          "Severity": "HIGH",
          "CvssScore": 7.5,
          "Description": "Prototype pollution in lodash..."
        }
      ],
      "NextSafeVersion": "4.17.21",
      "NextSafeVersionPublishedAt": "2021-02-20T00:00:00Z",
      "LatestVersion": "4.17.21",
      "LatestVersionPublishedAt": "2021-02-20T00:00:00Z",
      "UpgradeRisk": "Low",
      "CurrentVersionIsDeprecated": false
    }
  ]
}
```

| Field | Description |
|-------|-------------|
| `Total` | Number of vulnerable dependencies |
| `Dependencies[].DependencyName` | Original filename from the dependency check report |
| `Dependencies[].Ecosystem` | Package ecosystem (`Npm`, `Maven`, `NuGet`, `PyPi`, `Cargo`, `Go`, `RubyGems`). Use lowercase when calling `get_dependency_upgrade_advice`. |
| `Dependencies[].PackageName` | Parsed package name for use with the advisor tool |
| `Dependencies[].Version` | Parsed version string |
| `Dependencies[].PackageUrl` | Package URL (PURL) for reference |
| `Dependencies[].VulnerabilityCount` | Number of CVEs affecting this dependency |
| `Dependencies[].RiskScore` | Combined risk score (higher = more urgent) |
| `Dependencies[].Vulnerabilities` | List of individual CVE entries |
| `Dependencies[].NextSafeVersion` | The nearest version with no known CVEs. `null` if no clean version was found. **Always upgrade to this version.** |
| `Dependencies[].NextSafeVersionPublishedAt` | Publish date of the next safe version, or `null` |
| `Dependencies[].LatestVersion` | The newest available version (informational only), or `null` |
| `Dependencies[].LatestVersionPublishedAt` | Publish date of the latest version, or `null` |
| `Dependencies[].UpgradeRisk` | `Low`, `Medium`, or `High` based on semver distance between current and next safe version. `null` if upgrade advice was unavailable. |
| `Dependencies[].CurrentVersionIsDeprecated` | `true` if the current version has been deprecated |

## Response Schema: DependencyUpgradeAdvice

```json
{
  "Ecosystem": "Npm",
  "PackageName": "lodash",
  "CurrentVersion": "4.17.10",
  "CurrentVersionPublishedAt": "2018-04-24T00:00:00Z",
  "CurrentVersionIsDeprecated": false,
  "FoundNextCleanVersion": true,
  "NextCleanVersion": "4.17.21",
  "NextCleanMessage": "",
  "NextCleanVersionPublishedAt": "2021-02-20T00:00:00Z",
  "FoundLatestVersion": true,
  "LatestVersion": "4.17.21",
  "LatestHasAnyAdvisories": false,
  "LatestHasAnyCveAliases": false,
  "LatestMessage": "",
  "LatestVersionPublishedAt": "2021-02-20T00:00:00Z",
  "HasPotentialBreakingChanges": false,
  "UpgradeRisk": "Low",
  "Success": true,
  "ErrorMessage": null
}
```

| Field | Description |
|-------|-------------|
| `NextCleanVersion` | The nearest version with no known CVEs. **Always upgrade to this version.** |
| `NextCleanVersionPublishedAt` | Publish date of the next clean version |
| `FoundNextCleanVersion` | `true` if a clean version was found |
| `LatestVersion` | The newest available version (informational only, do not use for upgrades) |
| `UpgradeRisk` | `Low`, `Medium`, or `High` based on semver distance between current and next clean |
| `HasPotentialBreakingChanges` | `true` if the upgrade crosses a major version boundary |
| `CurrentVersionIsDeprecated` | `true` if the current version has been deprecated |
| `Success` | `false` if the lookup failed (check `ErrorMessage`) |
| `ErrorMessage` | Reason for failure (e.g., package not indexed, unlisted, private feed) |

---

## Decision Tree

Upgrade advice is returned inline with each dependency in the `get_dependency_vulnerabilities` response. Use `get_dependency_upgrade_advice` only if you need deeper detail (e.g. `HasPotentialBreakingChanges`, `NextCleanMessage`, `LatestHasAnyAdvisories`).

```
For each vulnerable dependency (highest RiskScore first):

1. Check the inline upgrade fields (NextSafeVersion, UpgradeRisk, etc.)

2. If NextSafeVersion is null:
   → Flag for manual replacement
   → Optionally call get_dependency_upgrade_advice for ErrorMessage detail
   → Suggest searching for an alternative package

3. If NextSafeVersion exists AND UpgradeRisk == "Low":
   → Auto-apply: edit manifest, set version to NextSafeVersion

4. If NextSafeVersion exists AND UpgradeRisk == "Medium" or "High":
   → Propose to user:
     - Current: {Version}
     - Upgrade to: {NextSafeVersion} ({NextSafeVersionPublishedAt})
     - Latest: {LatestVersion} ({LatestVersionPublishedAt})
     - Risk: {UpgradeRisk}
   → Optionally call get_dependency_upgrade_advice for HasPotentialBreakingChanges detail
   → Wait for confirmation before applying

5. If CurrentVersionIsDeprecated is true:
   → Inform the user the current version is deprecated
   → Recommend upgrading regardless of risk level
```

---

## Ecosystem Manifest Mapping

| Ecosystem | Manifest Files | Version Pattern |
|-----------|---------------|-----------------|
| npm | `package.json` | `"packageName": "^version"` |
| maven | `pom.xml` | `<version>version</version>` inside `<dependency>` |
| nuget | `*.csproj`, `Directory.Packages.props` | `Version="version"` in `<PackageReference>` |
| pypi | `requirements.txt` | `packageName==version` |
| cargo | `Cargo.toml` | `packageName = "version"` under `[dependencies]` |
| go | `go.mod` | `require module/path vversion` |
| rubygems | `Gemfile` | `gem 'packageName', '~> version'` |

---

## Ecosystem Restore and Build Commands

| Ecosystem | Restore | Build |
|-----------|---------|-------|
| npm | `npm install` | `npm run build` (if build script exists) |
| maven | `mvn install -DskipTests` | `mvn compile` |
| nuget | `dotnet restore` | `dotnet build` |
| pypi | `pip install -r requirements.txt` | (language-dependent) |
| cargo | `cargo build` | `cargo build` |
| go | `go mod tidy` | `go build ./...` |
| rubygems | `bundle install` | (language-dependent) |

---

## Error Handling

| Scenario | Action |
|----------|--------|
| No vulnerabilities found | Report clean status and stop |
| No dependency check report for this branch | Inform user that a dependency analysis has not been run on this branch |
| Advisor timeout or failure for a dependency | Skip it, continue with remaining dependencies, report skipped at end |
| Manifest file not found for a dependency | Report that the manifest could not be located; suggest manual upgrade |
| Build fails after upgrades | Report which upgrades were applied and the build error |
| MCP server not configured | Inform the user that Qualimetry Enterprise MCP is required |
| Package not indexed / unlisted / private feed | Flag for manual replacement with the advisor's error message |
