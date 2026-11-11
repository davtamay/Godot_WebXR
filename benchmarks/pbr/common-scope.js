// Identical queue-submit GPU interval for every engine. No native profiler counters.
(() => {
    const originalSubmit = GPUQueue.prototype.submit;
    const queues = new WeakMap();
    const pending = new Set();
    const scope = window.queueScope = { collecting: false, samples: [], errors: [], dropped: 0, submissions: 0, features: [], profile: window.PROFILE_GPU !== false };
    scope.start = () => { scope.samples = []; scope.errors = []; scope.dropped = 0; scope.submissions = 0; scope.collecting = true; };
    scope.stop = async () => { scope.collecting = false; await Promise.all([...pending]); return { samples: scope.samples, errors: scope.errors, dropped: scope.dropped, submissions: scope.submissions, features: scope.features, profile: scope.profile }; };
    const requestDevice = GPUAdapter.prototype.requestDevice;
    GPUAdapter.prototype.requestDevice = async function(descriptor = {}) {
        const features = new Set(descriptor.requiredFeatures || []);
        if (this.features.has('timestamp-query')) features.add('timestamp-query');
        const device = await requestDevice.call(this, { ...descriptor, requiredFeatures: [...features] });
        queues.set(device.queue, { device, slots: [] });
        scope.features.push({ features: [...device.features], adapter: { vendor: this.info?.vendor, architecture: this.info?.architecture, description: this.info?.description } });
        return device;
    };
    function slotFor(state) {
        let slot = state.slots.find(s => !s.busy);
        if (!slot && state.slots.length < 32) {
            slot = { query: state.device.createQuerySet({ type: 'timestamp', count: 2 }),
                resolve: state.device.createBuffer({ size: 256, usage: GPUBufferUsage.QUERY_RESOLVE | GPUBufferUsage.COPY_SRC }),
                read: state.device.createBuffer({ size: 256, usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ }), busy: false };
            state.slots.push(slot);
        }
        return slot;
    }
    GPUQueue.prototype.submit = function(buffers) {
        const record = scope.collecting ? { ordinal: ++scope.submissions, at: performance.now() } : null;
        const state = queues.get(this);
        if (!scope.profile || !state?.device.features.has('timestamp-query')) return originalSubmit.call(this, buffers);
        const slot = slotFor(state);
        if (!slot) { if (record) scope.dropped++; return originalSubmit.call(this, buffers); }
        slot.busy = true;
        const begin = state.device.createCommandEncoder();
        begin.beginComputePass({ timestampWrites: { querySet: slot.query, beginningOfPassWriteIndex: 0 } }).end();
        const end = state.device.createCommandEncoder();
        end.beginComputePass({ timestampWrites: { querySet: slot.query, endOfPassWriteIndex: 1 } }).end();
        end.resolveQuerySet(slot.query, 0, 2, slot.resolve, 0);
        end.copyBufferToBuffer(slot.resolve, 0, slot.read, 0, 16);
        const result = originalSubmit.call(this, [begin.finish(), ...buffers, end.finish()]);
        let work;
        work = slot.read.mapAsync(GPUMapMode.READ).then(() => {
            const times = new BigUint64Array(slot.read.getMappedRange());
            const delta = times[1] - times[0];
            if (times[1] < times[0]) throw new Error('Reversed GPU timestamps');
            if (record) scope.samples.push({ ...record, gpuMs: Number(delta) / 1e6 });
        }).catch(e => { if (record) scope.errors.push(String(e)); }).finally(() => {
            if (slot.read.mapState === 'mapped') slot.read.unmap();
            slot.busy = false; pending.delete(work);
        });
        pending.add(work);
        return result;
    };
})();
