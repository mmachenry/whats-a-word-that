import InfiniteScroll from 'react-infinite-scroll-component'

interface IProps {
  host: string;
  members: string[];
}

export default (props: IProps) => {
  return (
    <>
      <ol>
        <InfiniteScroll
          height="200px"
          dataLength={props.members.length}
          next={props.next}
          hasMore={props.hasMore}
          loader={<h4>Loading...</h4>}
          endMessage={
            <p style={{ textAlign: 'center' }}>
              <b>Yay! You have seen it all</b>
            </p>
          }
        >
          {props.members.map((item,idx) => (
            <li key={idx}>{item}</li>
          ))}
        </InfiniteScroll>
      </ol>
    </>
  )
}
