package main

import (
	"encoding/json"
	"flag"
	"io/ioutil"
	"log"
	"os"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3/s3manager"
	"github.com/hashicorp/terraform/terraform"
)

const (
	usage = `Usage: update_kubconfig --tfstate=<PATH_TO_TERRAFORM_STATE_FILE> --kubeconfig=<PATH_TO_KUBECONFIG>`
)

var (
	stateFilePath      string
	kubeconfigFilePath string
)

func init() {
	flag.StringVar(&stateFilePath, "tfstate", "", "path to the generated terraform state file")
	flag.StringVar(&kubeconfigFilePath, "kubeconfig", "", "path to the new kubeconfig file")
}

func main() {
	flag.Parse()

	if stateFilePath == "" {
		log.Fatal(usage)
	}

	if kubeconfigFilePath == "" {
		log.Fatal(usage)
	}

	if os.Getenv("AWS_ACCESS_KEY_ID") == "" {
		log.Fatal("env AWS_ACCESS_KEY_ID MUST be set")
	}

	if os.Getenv("AWS_SECRET_ACCESS_KEY") == "" {
		log.Fatal("env AWS_SECRET_ACCESS_KEY MUST be set")
	}

	var state terraform.State

	data, err := ioutil.ReadFile(stateFilePath)
	if err != nil {
		log.Fatalf("failed to read terraform state file %q: %v", stateFilePath, err)
	}

	if err := json.Unmarshal(data, &state); err != nil {
		log.Fatalf("failed to unmarshal the state file %q: %v", stateFilePath, err)
	}

	var bucketName, region string

	for _, m := range state.Modules {
		for k := range m.Resources {
			if k == "aws_s3_bucket.tectonic" {
				bucketName = m.Resources[k].Primary.Attributes["bucket"]
				region = m.Resources[k].Primary.Attributes["region"]
				break
			}
		}
	}

	if bucketName == "" || region == "" {
		log.Fatalf("failed to find s3 bucket name or region in the state file")
	}

	// The session the S3 Uploader will use
	sess := session.Must(session.NewSession(&aws.Config{Region: aws.String(region)}))

	// Create an uploader with the session and default options
	uploader := s3manager.NewUploader(sess)

	f, err := os.Open(kubeconfigFilePath)
	if err != nil {
		log.Fatalf("failed to open kubeconfig: %v", err)
	}
	defer f.Close()

	// Upload the file to S3.
	_, err = uploader.Upload(&s3manager.UploadInput{
		Bucket: aws.String(bucketName),
		Key:    aws.String("kubeconfig"),
		Body:   f,
	})
	if err != nil {
		log.Fatalf("failed to upload kubeconfig:, %v", err)
	}

	log.Println("KUBECONFIG updated successfully!")
}
