/** @checkup-agent — ecosystem-wide reserved checkup consumer ID */
export const CHECKUP_AGENT_ID = '@checkup-agent'
export const CHECKUP_INBOX_TOPIC = '@checkup-agent.inbox'

export function isCheckupAgentId(id: string): boolean {
  return id === CHECKUP_AGENT_ID
}
