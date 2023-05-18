import { workletContext } from "./WorkletGlobalScope";

/**
 * All of the classes or functions which are loaded into the AudioWorkletGlobalScope
 */
const workletC = new Map();
const wContext = new Set(); 

/**
 * Add a class to the AudioWorkletGlobalScope
 */
export function addToWorklet(classOrFunction:any) {
    wContext.add(classOrFunction);
}
/**
 * Register a processor in the AudioWorkletGlobalScope with the given name
 */
export function registerProcessor(name:any, classDesc:any) {
    const processor = /* javascript */ `registerProcessor("${name}", ${classDesc})`;
    workletC.set(name, processor);
}
/**
 * Get all of the modules which have been registered to the AudioWorkletGlobalScope
 */
export function getWorkletLocalScope(name:any) {
    let w2 = new Set(); 
    workletContext.forEach(item => {
        w2.add(item);
    });

    wContext.forEach(item => {
        w2.add(item);
    });

    w2.add( workletC.get(name) );
    
    return Array.from(w2).join("\n");
}
//# sourceMappingURL=WorkletGlobalScope.js.map