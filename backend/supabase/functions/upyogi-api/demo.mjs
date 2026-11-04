export const demoSeed = 'sulh-demo-v2';
export function isDemoScenario(booking, service) {
  return booking?.data?.demoScenario === true && service?.is_demo === true && service?.data?.demoSeed === demoSeed;
}
export function nextDemoStatus(status, skipPayment) {
  if (skipPayment === true && status === 'Completed') return 'Completed';
  if (!skipPayment) {
    const next = {Requested:'Accepted', Accepted:'OnTheWay', OnTheWay:'Completed'}[status];
    if (next) return next;
  }
  throw Error('invalid_demo_transition');
}
