export const beautifyObject = (obj: any): any => {
  const cloneObj = { ...obj };

  for (const [key, value] of Object.entries(cloneObj)) {
    console.log("\x1b[36m%s\x1b[0m", `${key}: ${value}`);
  }

  return obj;
};
