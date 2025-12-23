package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
)

// Config holds the configuration for the deployment
type Config struct {
	AppName     string
	Action      string
	Environment string

	// Provisioning Params
	VlanTag   string
	VmIp      string
	CpuCores  string
	RamMb     string
	DiskGb    string
	SshPubKey string
	StatePath string
}

func main() {
	appName := flag.String("app", "", "Application Name")
	action := flag.String("action", "provision", "Action to perform: provision, configure")
	
	// Provisioning flags
	vlanTag := flag.String("vlan", "20", "VLAN Tag")
	vmIp := flag.String("ip", "", "Target IP Address")
	cpuCores := flag.String("cpu", "2", "CPU Cores")
	ramMb := flag.String("ram", "4096", "RAM in MB")
	diskGb := flag.String("disk", "20G", "Disk Size")
	sshPubKey := flag.String("ssh-key", "", "SSH Public Key")
	statePath := flag.String("state-path", "/opt/terraform/terraform.tfstate", "Path to Terraform state file")

	flag.Parse()

	if *appName == "" {
		log.Fatal("App name is required")
	}

	cfg := Config{
		AppName:   *appName,
		Action:    *action,
		VlanTag:   *vlanTag,
		VmIp:      *vmIp,
		CpuCores:  *cpuCores,
		RamMb:     *ramMb,
		DiskGb:    *diskGb,
		SshPubKey: *sshPubKey,
		StatePath: *statePath,
	}

	if err := run(cfg); err != nil {
		log.Fatalf("Error: %v", err)
	}
}

func run(cfg Config) error {
	fmt.Printf("Running %s for %s...\n", cfg.Action, cfg.AppName)

	switch cfg.Action {
	case "provision":
		return runTerraform(cfg)
	case "configure":
		return runAnsible(cfg)
	default:
		return fmt.Errorf("unknown action: %s", cfg.Action)
	}
}

func runTerraform(cfg Config) error {
	workDir := "terraform"

	// Ensure state directory exists
	stateDir := filepath.Dir(cfg.StatePath)
	if err := os.MkdirAll(stateDir, 0755); err != nil {
		return fmt.Errorf("failed to create state directory %s: %w", stateDir, err)
	}

	// 1. Terraform Init
	fmt.Println("Initializing Terraform...")
	// Pass backend config to set the state path dynamically
	initCmd := exec.Command("terraform", "init", fmt.Sprintf("-backend-config=path=%s", cfg.StatePath))
	initCmd.Dir = workDir
	initCmd.Stdout = os.Stdout
	initCmd.Stderr = os.Stderr
	if err := initCmd.Run(); err != nil {
		return fmt.Errorf("terraform init failed: %w", err)
	}

	// 2. Workspace Management
	// Try to select, if fails, create new
	fmt.Printf("Selecting workspace '%s'...\n", cfg.AppName)
	selectCmd := exec.Command("terraform", "workspace", "select", cfg.AppName)
	selectCmd.Dir = workDir
	
	if err := selectCmd.Run(); err != nil {
		fmt.Printf("Workspace '%s' not found, creating...\n", cfg.AppName)
		createCmd := exec.Command("terraform", "workspace", "new", cfg.AppName)
		createCmd.Dir = workDir
		createCmd.Stdout = os.Stdout
		createCmd.Stderr = os.Stderr
		if err := createCmd.Run(); err != nil {
			return fmt.Errorf("failed to create workspace: %w", err)
		}
	}

	// 3. Terraform Apply
	fmt.Println("Applying Terraform configuration...")
	args := []string{
		"apply", "-auto-approve",
		fmt.Sprintf("-var=app_name=%s", cfg.AppName),
		fmt.Sprintf("-var=vlan_tag=%s", cfg.VlanTag),
		fmt.Sprintf("-var=vm_target_ip=%s", cfg.VmIp),
		fmt.Sprintf("-var=vm_cpu_cores=%s", cfg.CpuCores),
		fmt.Sprintf("-var=vm_ram_mb=%s", cfg.RamMb),
		fmt.Sprintf("-var=vm_disk_gb=%s", cfg.DiskGb),
	}

	// Only pass SSH key if provided (might be via env var TF_VAR_ssh_public_key instead)
	if cfg.SshPubKey != "" {
		args = append(args, fmt.Sprintf("-var=ssh_public_key=%s", cfg.SshPubKey))
	}

	applyCmd := exec.Command("terraform", args...)
	applyCmd.Dir = workDir
	applyCmd.Stdout = os.Stdout
	applyCmd.Stderr = os.Stderr
	
	if err := applyCmd.Run(); err != nil {
		return fmt.Errorf("terraform apply failed: %w", err)
	}

	return nil
}

func runAnsible(cfg Config) error {
	fmt.Println("Running Ansible...")
	// Placeholder for Ansible logic
	return nil
}
