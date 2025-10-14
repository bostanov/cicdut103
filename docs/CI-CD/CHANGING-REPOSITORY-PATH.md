# How to Change the 1C Repository Path

The path to the 1C configuration repository is managed in the `ci/config/ci-settings.json` file.

## Steps to change the path

1.  Open `ci/config/ci-settings.json`.
2.  Locate the `repository.url` key.
3.  Update its value to the new repository path.

### Examples

**File-based repository:**

```json
"url": "file://C:/1crepository/new-path"
```

**Server-based repository:**

For a repository on a server, use the `tcp://` protocol.

```json
"url": "tcp://your-1c-server:1541/YourRepositoryName"
```

4.  If the repository requires authentication, ensure the `user` is correct and the password is set in the `REPO_PWD` CI/CD variable in GitLab.
5.  After committing this change, you may need to manually run the `sync` job from the GitLab UI to pull the latest configuration.
