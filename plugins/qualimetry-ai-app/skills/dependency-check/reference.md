# Dependency Check Reference

## MCP Tools

### get_dependency_vulnerabilities

Retrieves all dependency vulnerabilities for a repository branch from the latest Qualimetry analysis.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `repositoryName` | string | Yes | The repository name, e.g. `owner/repo-name`. Case-insensitive; the server normalises the value. |
| `branchName` | string | Yes | Current branch (from `git branch --show-current`) |
| `includeSuppressed` | bool | No | Default `false`. When `true`, each dependency also carries `SuppressedVulnerabilities` - the CVEs an approved suppression removed from the report, with the scope, requester, reason and expiry behind each one. |
| `cve` | string | No | Narrow the response to a single CVE across every dependency, e.g. `CVE-2020-28500`. |
| `analysisName` | string | No | The analysis project name for mono-repo disambiguation. Case-insensitive. Leave empty for single-project repositories. |

**Returns:** JSON object with `Total` count and `Dependencies` array.

### get_dependency_suppressions

Retrieves the dependency suppressions that apply to a repository branch: the CVEs somebody has asked to accept, who asked, why, how widely the decision applies, and when it runs out. Results are grouped by dependency, then by identifier.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `repositoryName` | string | Yes | The repository name, e.g. `owner/repo-name`. Case-insensitive; the server normalises the value. |
| `branchName` | string | No | Current branch (from `git branch --show-current`). Leave empty for every suppression that reaches the repository. |
| `state` | string | No | Filter by state: `REQUESTED`, `APPROVED`, `REJECTED`, or `EXPIRED`. Default returns the active suppressions. |
| `includeExpired` | bool | No | Default `false`. When `true`, suppressions whose expiry date has passed are included. |
| `analysisName` | string | No | The analysis project name for mono-repo disambiguation. Case-insensitive. Leave empty for single-project repositories. |

**Returns:** JSON `DependencySuppressionsResult` object.

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
          "Description": "Prototype pollution in lodash...",
          "SuppressionPending": false
        }
      ],
      "NextSafeVersion": "4.17.21",
      "NextSafeVersionPublishedAt": "2021-02-20T00:00:00Z",
      "LatestVersion": "4.17.21",
      "LatestVersionPublishedAt": "2021-02-20T00:00:00Z",
      "UpgradeRisk": "Low",
      "CurrentVersionIsDeprecated": false,
      "SuppressionExpiringSoon": false,
      "SuppressedVulnerabilities": []
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
| `Dependencies[].Vulnerabilities[].SuppressionPending` | `true` when a suppression has been requested for this CVE and not yet approved. Pending requests are not applied, so the CVE is still listed, but it is not work to do. Report it and leave it alone. |
| `Dependencies[].NextSafeVersion` | The nearest version with no known CVEs. `null` if no clean version was found. **Always upgrade to this version.** |
| `Dependencies[].NextSafeVersionPublishedAt` | Publish date of the next safe version, or `null` |
| `Dependencies[].LatestVersion` | The newest available version (informational only), or `null` |
| `Dependencies[].LatestVersionPublishedAt` | Publish date of the latest version, or `null` |
| `Dependencies[].UpgradeRisk` | `Low`, `Medium`, or `High` based on semver distance between current and next safe version. `null` if upgrade advice was unavailable. |
| `Dependencies[].CurrentVersionIsDeprecated` | `true` if the current version has been deprecated |
| `Dependencies[].SuppressionExpiringSoon` | `true` when an approved suppression covering this dependency expires within 15 days. The findings it hides are about to return. |
| `Dependencies[].SuppressedVulnerabilities` | Only populated when `includeSuppressed` is `true`. The CVEs an approved suppression removed from the report, each with `Name`, `Severity`, `SuppressionState`, `SuppressionScope`, `SuppressionScopeName`, `RequesterName`, `ExpiresAt`, `IsFalsePositive` and `Reason`. |

## Response Schema: DependencySuppressionsResult

```json
{
  "Total": 2,
  "Dependencies": [
    {
      "DependencyName": "lodash-4.17.10.tgz",
      "Suppressions": [
        {
          "Identifier": "CVE-2020-28500",
          "State": "Approved",
          "Scope": "Repository",
          "ScopeName": "organisation/my-project",
          "RequesterName": "A. Developer",
          "RequestedDateTime": "2026-07-14T09:12:00Z",
          "ExpiresAt": "2026-10-14T00:00:00Z",
          "IsFalsePositive": true,
          "Reason": "The vulnerable code path is not reachable from this service."
        }
      ]
    }
  ]
}
```

| Field | Description |
|-------|-------------|
| `Total` | Number of suppressions returned |
| `Dependencies[].DependencyName` | The dependency the suppressions apply to |
| `Suppressions[].Identifier` | The CVE or package identifier being suppressed |
| `Suppressions[].State` | `Requested`, `Approved`, `Rejected`, or `Expired`. `Expired` is worked out from `ExpiresAt`, so an approved suppression past its date reads as expired. |
| `Suppressions[].Scope` | How widely the decision applies: all projects, an ensemble, a repository, or a single project |
| `Suppressions[].ScopeName` | The name of the thing the scope points at |
| `Suppressions[].RequesterName` | Who asked for the suppression |
| `Suppressions[].RequestedDateTime` | When it was asked for |
| `Suppressions[].ExpiresAt` | When the suppression stops applying. The finding returns to the report after this date. |
| `Suppressions[].IsFalsePositive` | `true` when the request was raised as a false positive rather than an accepted risk |
| `Suppressions[].Reason` | The written justification recorded with the request |

Only `Approved` suppressions that have not expired are applied by the scanner. A `Requested` suppression changes nothing about the report; it only tells you the CVE is already being dealt with.

**Raising, approving and rejecting suppressions are human actions in the Qualimetry dashboard.** These tools are read-only.

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
   and the suppression flags (SuppressionPending, SuppressionExpiringSoon)

2. If every CVE on the dependency has SuppressionPending == true:
   → Do not upgrade; a suppression request is waiting for approval
   → Report it and move to the next dependency

3. If NextSafeVersion is null:
   → Flag for manual replacement
   → Optionally call get_dependency_upgrade_advice for ErrorMessage detail
   → Suggest searching for an alternative package

4. If NextSafeVersion exists AND UpgradeRisk == "Low":
   → Auto-apply: edit manifest, set version to NextSafeVersion

5. If NextSafeVersion exists AND UpgradeRisk == "Medium" or "High":
   → Propose to user:
     - Current: {Version}
     - Upgrade to: {NextSafeVersion} ({NextSafeVersionPublishedAt})
     - Latest: {LatestVersion} ({LatestVersionPublishedAt})
     - Risk: {UpgradeRisk}
   → Optionally call get_dependency_upgrade_advice for HasPotentialBreakingChanges detail
   → Wait for confirmation before applying

6. If CurrentVersionIsDeprecated is true:
   → Inform the user the current version is deprecated
   → Recommend upgrading regardless of risk level

7. If SuppressionExpiringSoon is true:
   → Tell the user the suppression runs out within 15 days
   → Treat the dependency as work that is coming back
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
| No vulnerabilities found | Report clean status and stop; say whether anything was suppressed |
| `get_dependency_suppressions` missing from the server's tool list | The deployment is older than the suppression tools. Say so in one line and carry on with the upgrade workflow. |
| A CVE the user expected is absent | An approved suppression removed it at scan time. Re-run with `includeSuppressed` set to `true`, or call `get_dependency_suppressions`. |
| No dependency check report for this branch | Inform user that a dependency analysis has not been run on this branch |
| Advisor timeout or failure for a dependency | Skip it, continue with remaining dependencies, report skipped at end |
| Manifest file not found for a dependency | Report that the manifest could not be located; suggest manual upgrade |
| Build fails after upgrades | Report which upgrades were applied and the build error |
| MCP server not configured | Inform the user that Qualimetry Enterprise MCP is required |
| Package not indexed / unlisted / private feed | Flag for manual replacement with the advisor's error message |
