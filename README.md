# apxsp-async-actions

TODO!

---

## Getting Started

Run the following command to create a scratch org:

```
sf org create scratch -f config/project-scratch-def.json -w 5 -y 30 -a YOUR_ORG_NAME
```

Once created, install the necessary dependencies referenced in [`sfdx-project.json`](sfdx-project.json) by running these commands:

```
# Get package versions
sf package version list -p PACKAGE_ALIAS
# Find the specified version id and install that package
sf package install -p PACKAGE_VERSION_ID -w 5
```

Once all dependencies are installed, push the source to your target environment:

```
sf project source deploy
```
