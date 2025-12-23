package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
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

	// Validate inputs
	if err := validateConfig(cfg); err != nil {
		log.Fatalf("Validation error: %v", err)
	}

	if err := run(cfg); err != nil {
		log.Fatalf("Error: %v", err)
	}
}

// validateConfig performs input validation
func validateConfig(cfg Config) error {
	// Validate VLAN tag
	if cfg.VlanTag != "10" && cfg.VlanTag != "20" {
		return fmt.Errorf("VLAN tag must be '10' (DMZ/production) or '20' (internal dev), got '%s'", cfg.VlanTag)
	}

	// Validate IP address matches VLAN subnet
	if err := validateIP(cfg.VmIp, cfg.VlanTag); err != nil {
		return err
	}

	return nil
}

// validateIP ensures IP matches the expected VLAN subnet
func validateIP(ip, vlanTag string) error {
	// Expected patterns based on VLAN
	var expectedPattern string
	switch vlanTag {
	case "10":
		expectedPattern = "^192\\.168\\.10\\.([0-9]{1,3})$"
	case "20":
		expectedPattern = "^192\\.168\\.20\\.([0-9]{1,3})$"
	default:
		return fmt.Errorf("unknown VLAN tag: %s", vlanTag)
	}

	// Check pattern
	regex := regexp.MustCompile(expectedPattern)
	matches := regex.FindStringSubmatch(ip)
	if matches == nil {
		vlanDesc := "internal dev"
		if vlanTag == "10" {
			vlanDesc = "DMZ/production"
		}
		return fmt.Errorf("IP %s does not match 192.168.%s.x pattern for VLAN %s (%s)", ip, vlanTag, vlanTag, vlanDesc)
	}

	// Validate third octet is in valid range (10-254)
	lastOctet := matches[1]
	octet, err := strconv.Atoi(lastOctet)
	if err != nil {
		return fmt.Errorf("invalid IP octet: %s", lastOctet)
	}

	if octet < 10 || octet > 254 {
		return fmt.Errorf("IP octet must be between 10 and 254, got %d", octet)
	}

	return nil
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
