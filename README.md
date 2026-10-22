# E-Waste Collection and Recycling Portal — DevOps Demo

A static, responsive portal plus a Windows-friendly Jenkins/Docker/Kubernetes learning pipeline. All centre records and counts are synthetic sample data.

## Files

- `index.html` — five sample collection centres, device categories, schedules, recycling guidance, status dashboard, search, and a browser-session schedule update form.
- `Dockerfile` — packages the portal in Nginx.
- `Jenkinsfile` — Jenkins Declarative Pipeline for parallel validation, image build, local smoke test, artifact archiving, Docker Hub push, Kubernetes rollout, and rollback.
- `deployment.yaml` — two-replica Kubernetes Deployment and NodePort Service.

## 1. Create GitHub repository and clone it

Create an empty public or private GitHub repository named `e-waste-collection-portal` (do not initialize with README if you will push this folder as-is). In a terminal:

```bat
cd %USERPROFILE%\Downloads
git clone https://github.com/YOUR_GITHUB_USERNAME/e-waste-collection-portal.git
cd e-waste-collection-portal
```

Copy these four project files and this README into the cloned folder. Set Git identity if needed:

```bat
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"
```

Initial commit:

```bat
git add index.html Dockerfile Jenkinsfile deployment.yaml README.md
git commit -m "Initial commit: create e-waste collection and recycling portal"
git push -u origin main
```

Enhancement commit: edit `index.html` (for example, update one schedule or add another status detail), then:

```bat
git add index.html
git commit -m "Enhance portal with processing status dashboard and collection updates"
git push
```

If GitHub uses a browser sign-in or personal access token, authenticate through Git Credential Manager. Do not put your GitHub password or token directly into commands or source files.

## 2. Run and test locally

Requirements: Git, Docker Desktop, VS Code, Jenkins, and `kubectl`. Open Docker Desktop and wait for the engine to start.

```bat
docker build -t YOUR_DOCKERHUB_USERNAME/e-waste-portal:v1 .
docker run --name e-waste-local -d -p 18087:80 YOUR_DOCKERHUB_USERNAME/e-waste-portal:v1
```

Open `http://localhost:18087`. Verify the five centres, dashboard, search, and schedule-update form. Test the HTTP response:

```bat
curl.exe -I http://localhost:18087
docker logs e-waste-local
docker rm -f e-waste-local
```

Replace `YOUR_DOCKERHUB_USERNAME` with your actual Docker Hub username in the commands, `Jenkinsfile`, and `deployment.yaml` image placeholder.

## 3. Jenkins setup

1. Install/use Jenkins with Git and Pipeline support, and ensure the Jenkins service account can run `git`, `docker`, and `kubectl`.
2. Configure the job as **Pipeline script from SCM**, SCM Git, your repository URL, branch `*/main`, script path `Jenkinsfile`.
3. In Jenkins **Manage Jenkins → Credentials**, add:
   - `dockerhub-userpass`: Username with password/token; use a Docker Hub access token as the password.
   - `kubernetes-config`: Secret file containing a kubeconfig that can access the Docker Desktop Kubernetes cluster.
4. Edit `DOCKERHUB_USERNAME` in `Jenkinsfile` and replace the placeholder in `deployment.yaml`.
5. Start Docker Desktop, enable Kubernetes in Settings → Kubernetes, and wait until the cluster is running. Verify from a terminal using `kubectl config current-context` and `kubectl get nodes`.
6. Ensure Jenkins can use the same Docker engine and kubeconfig. For a Windows Jenkins service, check permissions and the service account's Docker Desktop access. The kubeconfig credential is passed to `kubectl` by Jenkins for the deployment stage.

The pipeline demonstrates at least two requested types:
- **Parallel stages:** HTML content tests and manifest tests run in parallel.
- **Parameterized build:** `RELEASE_MODE` chooses `STABLE` or `FAULTY_ROLLBACK_TEST`; `DEPLOY_TO_KUBERNETES` can skip deployment.
- **Archive artifacts:** key project files and image-inspection output are archived.
- **Conditional execution:** Kubernetes deployment runs only when its parameter is enabled.

## 4. Docker Hub push

The Jenkins pipeline logs in using the `dockerhub-userpass` credential and pushes `YOUR_DOCKERHUB_USERNAME/e-waste-portal:vBUILD_NUMBER`. Confirm the tag appears in Docker Hub. Do not commit credentials.

## 5. Kubernetes deploy and access

The pipeline applies `deployment.yaml`, sets the image to the build-specific tag, and waits for rollout health. The Service uses NodePort `30087`; try `http://localhost:30087` after the pods are Ready. If that NodePort is already in use, change `nodePort` to an unused value between 30000 and 32767.

Manual checks:

```bat
kubectl get deployments
kubectl get pods -l app=e-waste-portal
kubectl get services e-waste-portal
kubectl rollout history deployment/e-waste-portal
kubectl rollout status deployment/e-waste-portal
```

## 6. Deliberate failed rollout and automatic rollback demo

First run a successful build with `RELEASE_MODE=STABLE` so Kubernetes has a healthy revision. Then run a new Jenkins build with `RELEASE_MODE=FAULTY_ROLLBACK_TEST`.

The pipeline deliberately changes the readiness probe to `/faulty-health-check`, a path not served by the static portal. The new pods cannot become Ready; `kubectl rollout status` times out/fails, the pipeline collects diagnostics, runs `kubectl rollout undo`, and waits for the prior stable revision. The Jenkins build is marked FAILURE deliberately so the failed rollout is visible even though recovery succeeds.

Verify recovery:

```bat
kubectl rollout history deployment/e-waste-portal
kubectl get deployment e-waste-portal
kubectl get pods -l app=e-waste-portal
kubectl get service e-waste-portal
```

Open `http://localhost:30087` and verify the portal loads. Depending on your Jenkins and Kubernetes versions, inspect the stage console output for the rollout failure and rollback messages. After the faulty test, the previous stable ReplicaSet's readiness probe should be restored by `rollout undo`.

## Troubleshooting

- **Docker command fails in Jenkins:** ensure Docker Desktop is running and the Jenkins service account has permission to access its engine.
- **`kubectl` cannot connect:** confirm Docker Desktop Kubernetes is enabled and the `kubernetes-config` secret file points to the correct cluster/context.
- **Docker Hub push denied:** verify repository name, username, and access-token credential.
- **NodePort URL fails:** check `kubectl get pods`, `kubectl get svc`, and `kubectl describe deployment e-waste-portal`; ensure the cluster is healthy.
- **Jenkins `bat` steps fail on a Linux agent:** this Jenkinsfile targets a Windows agent. Use a Windows Jenkins agent or adapt `bat` commands to `sh`.
- **First deployment has no stable revision:** run the `STABLE` pipeline once before `FAULTY_ROLLBACK_TEST`.
