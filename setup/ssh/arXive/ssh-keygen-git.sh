#!/usr/bin/env bash
printf "%s\n" "$(tput bold)$(date) ${BASH_SOURCE[0]}$(tput sgr0)"

counter=0
subcounter=0
start_time=${SECONDS}

function new_step() {
    export counter=$((counter + 1))
    export subcounter=0
    echo ""
    echo "Step ${counter}: ${1}"
}

function sub_step() {
    export subcounter=$((subcounter + 1))
    echo ""
    echo "  Substep ${counter}.${subcounter}: ${1}"
}

function display_total_elapsed_time() {
    local total_elapsed_time=$((SECONDS - start_time))
    local total_minutes=$((total_elapsed_time / 60))
    local total_seconds=$((total_elapsed_time % 60))
    echo ""
    printf "Total elapsed time: %02d:%02d (MM:SS)\n" \
        "$total_minutes" "$total_seconds"
}

generate_key() {
    local service="$1"
    local key_name="id_${HOSTNAME}_${service}_ed25519"

    new_step "Create ${service} key: ${key_name}"

    ssh-keygen -t ed25519 \
        -f "${HOME}/.ssh/${key_name}" \
        -C "${HOSTNAME}-${service}"

    sub_step "Public key for ${service}"
    cat "${HOME}/.ssh/${key_name}.pub"
}

new_step "Configure SSH directory"
  sub_step "mkdir -p \"${HOME}/.ssh\""
            mkdir -p "${HOME}/.ssh"

  sub_step "chmod 700 \"${HOME}/.ssh\""
            chmod 700 "${HOME}/.ssh"

# ----------------------------------------------------------------------
# Preserve existing SSH config
# ----------------------------------------------------------------------

new_step "Preserve existing SSH config"

ssh_config="${HOME}/.ssh/config"

if [[ -f "${ssh_config}" ]]; then
    timestamp="$(date +%Y%m%d-%H%M%S)"
    backup="${ssh_config}.${timestamp}.bak"

    cp -p "${ssh_config}" "${backup}"

    echo "Saved:"
    echo "  ${backup}"
else
    echo "No existing SSH config."
fi

new_step "Generate keys"
  sub_step 'generate_key gitlab'
            generate_key gitlab
  sub_step 'generate_key bitbucket'
            generate_key bitbucket
  sub_step 'generate_key github'
            generate_key github

# ----------------------------------------------------------------------
# Write SSH config
# ----------------------------------------------------------------------

new_step "Write SSH config file"

cat > "${ssh_config}" <<EOF
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_${HOSTNAME}_github_ed25519
    IdentitiesOnly yes

Host gitlab.com
    HostName gitlab.com
    User git
    IdentityFile ~/.ssh/id_${HOSTNAME}_gitlab_ed25519
    IdentitiesOnly yes

Host bitbucket.org
    HostName bitbucket.org
    User git
    IdentityFile ~/.ssh/id_${HOSTNAME}_bitbucket_ed25519
    IdentitiesOnly yes
EOF

new_step "chmod 600 \"${ssh_config}\""
          chmod 600 "${ssh_config}"

new_step "show config via cat \"${ssh_config}\""
                          cat -n "${ssh_config}"

display_total_elapsed_time
