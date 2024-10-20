import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from '@/components/ui/accordion'

export function FAQs() {
  return (
    <Accordion type="single" collapsible className="w-full">
      <AccordionItem value="item-1">
        <AccordionTrigger>About</AccordionTrigger>
        <AccordionContent>
          Signals is an open source protocol for gathering, filtering and incentivizing sentiment in
          onchain communities.
        </AccordionContent>
      </AccordionItem>
      <AccordionItem value="item-2">
        <AccordionTrigger>How does it work?</AccordionTrigger>
        <AccordionContent>
          <ul className="list-disc list-inside">
            <li>Lock tokens against initiatives to surface important issues in your community.</li>
            <li>Longer locks have a multiple applied to the initial weight.</li>
            <li>The bonus weight decays linearly over time to its initial value.</li>
            <li>Anyone can add incentives to an initiative.</li>
            <li>Incentives are paid out when an initiative reaches a quorum of support.</li>
          </ul>
        </AccordionContent>
      </AccordionItem>
      <AccordionItem value="item-3">
        <AccordionTrigger>How do Incentives work?</AccordionTrigger>
        <AccordionContent>
          Incentives are ERC20 tokens that anyone can add to an initiative. Three recipients are
          baked into the protocol.
          <ul className="list-disc list-inside">
            <li>Protocol Fee: 5%</li>
            <li>Supporters: 30%</li>
            <li>Treasury: 65%</li>
          </ul>
          <p>
            The protocol fee is used to cover the cost of running the protocol. The supporter reward
            is paid out to the community members that support an initiative. The treasury reward is
            paid out to your community's treasury.
          </p>
          <p>These values are all configurable by the community.</p>
        </AccordionContent>
      </AccordionItem>
      <AccordionItem value="item-4">
        <AccordionTrigger>Are the contracts audited?</AccordionTrigger>
        <AccordionContent>
          Not yet. We are still in early development and are only deployed on Arbitrum Sepolia.
        </AccordionContent>
      </AccordionItem>
      <AccordionItem value="item-5">
        <AccordionTrigger>I want this!</AccordionTrigger>
        <AccordionContent>
          Great. We would love to hear from you! Please drop us a line at{' '}
          <a className="underline" href="mailto:hello@lighthouse.cx">
            hello@lighthouse.cx
          </a>
          .
        </AccordionContent>
      </AccordionItem>
    </Accordion>
  )
}
