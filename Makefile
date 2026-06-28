include .env

deploy-script:
	forge script script/DeployStep1.s.sol:DeployStep1 \
		--rpc-url $(BASE_SEPOLIA_RPC_URL) \
		--account testnetkey \
		--broadcast \
		--verify \
		--verifier etherscan \
		--etherscan-api-key $(ETHERSCAN_API_KEY)