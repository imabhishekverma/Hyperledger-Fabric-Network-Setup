package main

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/hyperledger/fabric-chaincode-go/shim"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type SmartContract struct { contractapi.Contract }

type Asset struct {
	ID       string `json:"ID"`
	Color    string `json:"color"`
	Size     int    `json:"size"`
	Owner    string `json:"owner"`
	AppraisedValue int `json:"appraisedValue"`
}

func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	assets := []Asset{
		{ID: "asset1", Color: "blue", Size: 5, Owner: "Tomoko", AppraisedValue: 300},
		{ID: "asset2", Color: "red", Size: 5, Owner: "Brad", AppraisedValue: 400},
	}
	for _, asset := range assets {
		if err := s.CreateAsset(ctx, asset.ID, asset.Color, asset.Size, asset.Owner, asset.AppraisedValue); err != nil { return err }
	}
	return nil
}

func (s *SmartContract) CreateAsset(ctx contractapi.TransactionContextInterface, id, color string, size int, owner string, value int) error {
	exists, err := s.AssetExists(ctx, id)
	if err != nil { return err }
	if exists { return fmt.Errorf("asset %s already exists", id) }
	return ctx.GetStub().PutState(id, mustJSON(Asset{ID: id, Color: color, Size: size, Owner: owner, AppraisedValue: value}))
}

func (s *SmartContract) ReadAsset(ctx contractapi.TransactionContextInterface, id string) (*Asset, error) {
	b, err := ctx.GetStub().GetState(id)
	if err != nil { return nil, err }
	if b == nil { return nil, fmt.Errorf("asset %s does not exist", id) }
	var asset Asset
	if err := json.Unmarshal(b, &asset); err != nil { return nil, err }
	return &asset, nil
}

func (s *SmartContract) UpdateAsset(ctx contractapi.TransactionContextInterface, id, color string, size int, owner string, value int) error {
	if exists, err := s.AssetExists(ctx, id); err != nil { return err } else if !exists { return fmt.Errorf("asset %s does not exist", id) }
	return ctx.GetStub().PutState(id, mustJSON(Asset{ID: id, Color: color, Size: size, Owner: owner, AppraisedValue: value}))
}

func (s *SmartContract) DeleteAsset(ctx contractapi.TransactionContextInterface, id string) error {
	if exists, err := s.AssetExists(ctx, id); err != nil { return err } else if !exists { return fmt.Errorf("asset %s does not exist", id) }
	return ctx.GetStub().DelState(id)
}

func (s *SmartContract) AssetExists(ctx contractapi.TransactionContextInterface, id string) (bool, error) {
	b, err := ctx.GetStub().GetState(id)
	return b != nil, err
}

func mustJSON(v interface{}) []byte { b, err := json.Marshal(v); if err != nil { panic(err) }; return b }

func main() {
	chaincode, err := contractapi.NewChaincode(&SmartContract{})
	if err != nil { panic(err) }
	server := &shim.ChaincodeServer{
		CCID:    os.Getenv("CHAINCODE_ID"),
		Address: os.Getenv("CHAINCODE_SERVER_ADDRESS"),
		CC:      chaincode,
		TLSProps: shim.TLSProperties{Disabled: true},
	}
	if err := server.Start(); err != nil { panic(err) }
}
