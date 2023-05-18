/**
 * All of the classes or functions which are loaded into the AudioWorkletGlobalScope
 * Modified by Courtney Brown 5/2023 -- just a fast solution to this tonejs bug -- need to report &/or find a better solution soon!!
 */
export var workletContext = new Set();
/**
 * Add a class to the AudioWorkletGlobalScope
 */
export function addToWorklet(classOrFunction:any) {
    workletContext.add(classOrFunction);
}
/**
 * Register a processor in the AudioWorkletGlobalScope with the given name
 */
export function registerProcessor(name:any, classDesc:any) {
    const processor = /* javascript */ `registerProcessor("${name}", ${classDesc})`;
    workletContext.add(processor);
}
/**
 * Get all of the modules which have been registered to the AudioWorkletGlobalScope
 */
export function getWorkletGlobalScope() {
    return Array.from(workletContext).join("\n");
}
//# sourceMappingURL=WorkletGlobalScope.js.map

export function getWorkletContextSet() {
    return workletContext;
}
