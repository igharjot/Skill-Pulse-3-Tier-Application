CLUSTER  ?= skillpulse
NAMESPACE ?= skillpulse
BACKEND_IMAGE  ?= trainwithshubham/skillpulse-backend:latest
FRONTEND_IMAGE ?= trainwithshubham/skillpulse-frontend:latest

.PHONY: up down build load apply status logs mysql restart

install-sealed-secrets: ## Install the Sealed Secrets controller into kube-system
	helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
	helm repo update
	helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets \
	  --namespace kube-system \
	  --set fullnameOverride=sealed-secrets-controller \
	  --wait
	@echo ""
	@echo "  Sealed Secrets controller is ready."
	@echo "  Now run:  make seal   (after editing k8s/05-secret-plain.yaml)"
	@echo ""
 
seal: ## Encrypt k8s/05-secret-plain.yaml → k8s/05-sealed-secret.yaml
	@if [ ! -f k8s/05-secret-plain.yaml ]; then \
	  echo "ERROR: k8s/05-secret-plain.yaml not found."; \
	  echo "       Copy it from the template, fill in real credentials, then re-run."; \
	  echo "       Template: k8s/05-secret-plain.yaml.example  (if present)"; \
	  exit 1; \
	fi
	kubeseal --format yaml \
	  --controller-name sealed-secrets-controller \
	  --controller-namespace kube-system \
	  < k8s/05-secret-plain.yaml \
	  > k8s/05-sealed-secret.yaml
	@echo ""
	@echo "  Sealed! k8s/05-sealed-secret.yaml is safe to commit."
	@echo "  IMPORTANT: Delete the plain file now:"
	@echo "             rm k8s/05-secret-plain.yaml"
	@echo ""
 
unseal-check: ## Verify the SealedSecret was decrypted correctly by the controller
	@echo "Checking that the Secret 'skillpulse-db' exists in namespace $(NAMESPACE)..."
	kubectl get secret skillpulse-db -n $(NAMESPACE) \
	  -o jsonpath='{range .data}{@}{"\n"}{end}'
	@echo ""
	@echo "  If you see base64 output above (not empty), decryption worked."

up: ## One-shot: build images, create cluster, load images, apply manifests
	$(MAKE) build
	kind create cluster --config k8s/kind-config.yaml --name $(CLUSTER)
	$(MAKE) install-sealed-secrets
	@if [ -f k8s/05-secret-plain.yaml ]; then \
	  $(MAKE) seal; \
	else \
	  echo "  SKIP: k8s/05-secret-plain.yaml not found — using existing 05-sealed-secret.yaml"; \
	  echo "  (This is expected if you already ran 'make seal' and deleted the plain file.)"; \
	fi
	$(MAKE) load
	$(MAKE) apply
	@echo
	@echo "  SkillPulse is live at http://localhost:8888"
	@echo

build: ## Build backend + frontend images for the host's architecture
	docker build -t $(BACKEND_IMAGE)  ./backend
	docker build -t $(FRONTEND_IMAGE) ./frontend

load: ## Push built images into the kind node
	kind load docker-image $(BACKEND_IMAGE)  --name $(CLUSTER)
	kind load docker-image $(FRONTEND_IMAGE) --name $(CLUSTER)

apply: ## Apply manifests and wait for rollouts
	kubectl apply -f k8s/00-namespace.yaml
	kubectl apply -f k8s/05-sealed-secret.yaml
	kubectl apply -f k8s/10-mysql.yaml \
	              -f k8s/20-backend.yaml \
	              -f k8s/30-frontend.yaml
	kubectl rollout status statefulset/mysql    -n $(NAMESPACE) --timeout=180s
	kubectl rollout status deployment/backend   -n $(NAMESPACE) --timeout=120s
	kubectl rollout status deployment/frontend  -n $(NAMESPACE) --timeout=60s

down: ## Delete the cluster
	kind delete cluster --name $(CLUSTER)

status: ## Quick health snapshot
	@kubectl get pods,svc,endpoints -n $(NAMESPACE)

logs: ## Tail all three workloads at once
	@kubectl logs -n $(NAMESPACE) -l 'app in (mysql,backend,frontend)' --all-containers --tail=50 -f --max-log-requests=10

mysql: ## Open a mysql shell into the StatefulSet pod
	kubectl exec -it -n $(NAMESPACE) mysql-0 -- mysql -uskillpulse -pskillpulse123 skillpulse

restart: ## Rebuild + reload images, roll backend + frontend
	$(MAKE) build
	$(MAKE) load
	kubectl rollout restart deployment/backend deployment/frontend -n $(NAMESPACE)
	kubectl rollout status  deployment/backend  -n $(NAMESPACE) --timeout=120s
	kubectl rollout status  deployment/frontend -n $(NAMESPACE) --timeout=60s
