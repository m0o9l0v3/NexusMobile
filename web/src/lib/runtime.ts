const runtime = (import.meta.env.VITE_RUNTIME as string | undefined) ?? "web";

export const isNativeRuntime = runtime === "native";
export const isWebRuntime = !isNativeRuntime;
export const runtimeName = runtime;
