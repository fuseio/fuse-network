async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const Migrations = await ethers.getContractFactory("Migrations");
  const migrations = await Migrations.deploy();

  console.log("Migrations deployed to:", migrations.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
