import { CHIMERA_BODIES, CHIMERA_HEADS, CHIMERA_TAILS } from "../../game/config/animals";

export function Chimera({ head, body, tail, small = false }: { head: number; body: number; tail: number; small?: boolean }) {
  return (
    <div className={`chimera ${small ? "chimera-small" : ""}`} aria-label="조립한 키메라 동물">
      <span className="tail">{CHIMERA_TAILS[tail]}</span>
      <span className="body-part">{CHIMERA_BODIES[body]}</span>
      <span className="head">{CHIMERA_HEADS[head]}</span>
      <span className="leg leg-a" />
      <span className="leg leg-b" />
    </div>
  );
}
