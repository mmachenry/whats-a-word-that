import InfiniteScroll from 'react-infinite-scroll-component'

interface IProps {
  host: string;
  members: string[];
}

export default (props: IProps) => {
  return (
    <>
      <ol>
        <ul>
          {props.members.map((title, idx) => ( <li key={idx}>{title}</li>)) }
        </ul>
      </ol>
    </>
  )
}
