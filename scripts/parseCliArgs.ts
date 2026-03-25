/** Args after `hardhat run script.ts --network leo -- ...` */
export function scriptArgv(): string[] {
  const dash = process.argv.indexOf("--");
  return dash >= 0 ? process.argv.slice(dash + 1) : [];
}

export function argValue(argv: string[], flag: string): string | undefined {
  const i = argv.indexOf(flag);
  if (i < 0 || i + 1 >= argv.length) return undefined;
  const v = argv[i + 1];
  return v.startsWith("-") ? undefined : v;
}
